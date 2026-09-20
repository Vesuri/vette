// Recover and export Macintosh A-line trap sites from one extracted CODE segment.
//
// Ghidra's 68000 language stops flow at an A-line word.  A raw $Axxx sweep is not
// acceptable: CODE resources contain inline data and jump tables.  This script
// starts only at established instruction fall-throughs / flow destinations,
// treats a trap as a two-byte returning boundary, resumes at the following word,
// and repeats until no more code or trap sites are discovered.
//
// Arg0 = output CSV (default: <program>_traps.csv)
// Arg1 = generated trap-name Lua table (default: ../tmp/trap_names.lua relative
//        to this script). Generate it with tools/gen_trap_names.py; absent names
//        are reported as ?OS_xx / ?TB_xxx, never guessed.
//@category Vette
import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.CodeUnit;
import ghidra.program.model.listing.Instruction;
import ghidra.program.model.listing.Listing;
import ghidra.program.model.mem.Memory;
import ghidra.program.model.symbol.SourceType;
import generic.jar.ResourceFile;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.InputStreamReader;
import java.io.PrintWriter;
import java.util.ArrayList;
import java.util.ArrayDeque;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import java.util.TreeMap;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class DumpTraps extends GhidraScript {
    private static final Pattern NAME_ROW = Pattern.compile(
        "\\[0x([0-9A-Fa-f]{4})\\]\\s*=\\s*\"([^\"]+)\"");
    private static final Pattern SEGMENT_ID = Pattern.compile("CODE_(\\d+)");

    private static final class TrapSite {
        final Address address;
        final int word;
        TrapSite(Address address, int word) { this.address = address; this.word = word; }
    }

    private int unsignedWord(Memory memory, Address address) throws Exception {
        return ((memory.getByte(address) & 0xff) << 8)
             | (memory.getByte(address.add(1)) & 0xff);
    }

    private boolean readableWord(Memory memory, Address address) {
        try {
            return (address.getOffset() & 1) == 0
                && memory.contains(address) && memory.contains(address.add(1));
        } catch (Exception e) {
            return false;
        }
    }

    private int trapNumber(int word) {
        return (word & 0x0800) != 0 ? 0x0800 | (word & 0x03ff) : word & 0x00ff;
    }

    private int baseWord(int word) {
        return 0xa000 | trapNumber(word);
    }

    private String flags(int word) {
        ArrayList<String> result = new ArrayList<>();
        if ((word & 0x0800) != 0) {
            if ((word & 0x0400) != 0) result.add("autoPop");
        } else {
            if ((word & 0x0400) != 0) result.add("trashA0");
            if ((word & 0x0200) != 0) result.add("sysHeap");
            if ((word & 0x0100) != 0) result.add("clearMem");
        }
        return String.join("|", result);
    }

    private String unknownName(int word) {
        if ((word & 0x0800) != 0) return String.format("?TB_%03X", word & 0x03ff);
        return String.format("?OS_%02X", word & 0xff);
    }

    private void readNames(BufferedReader reader, Map<Integer, String> exact,
                           Map<Integer, String> byNumber) throws Exception {
        String line;
        while ((line = reader.readLine()) != null) {
            Matcher m = NAME_ROW.matcher(line);
            if (!m.find()) continue;
            int word = Integer.parseInt(m.group(1), 16);
            String name = m.group(2);
            exact.put(word, name);
            byNumber.putIfAbsent(trapNumber(word), name);
        }
    }

    private void loadNames(String explicitPath, Map<Integer, String> exact,
                           Map<Integer, String> byNumber) throws Exception {
        if (explicitPath != null) {
            File file = new File(explicitPath);
            if (!file.isFile()) {
                printerr("DumpTraps: trap-name table not found: " + file);
                return;
            }
            try (BufferedReader reader = new BufferedReader(new FileReader(file))) {
                readNames(reader, exact, byNumber);
            }
            return;
        }
        ResourceFile root = getSourceFile().getParentFile().getParentFile();
        ResourceFile table = new ResourceFile(root, "tmp/trap_names.lua");
        if (!table.exists()) {
            printerr("DumpTraps: tmp/trap_names.lua missing; run tools/gen_trap_names.py");
            return;
        }
        try (BufferedReader reader = new BufferedReader(
                new InputStreamReader(table.getInputStream()))) {
            readNames(reader, exact, byNumber);
        }
    }

    private void addCandidate(ArrayDeque<Address> candidates, Address address,
                              Memory memory) {
        if (address != null && readableWord(memory, address)) candidates.addLast(address);
    }

    private void addStoredPcRelativeRoutine(ArrayDeque<Address> candidates,
                                            Instruction instruction,
                                            Memory memory) throws Exception {
        Address address = instruction.getAddress();
        int opcode = unsignedWord(memory, address);
        // LEA d16(PC),An immediately followed by MOVE.L An,(Am)+ is compiler
        // evidence for a stored procedure address, not merely an address-shaped
        // constant.  Intro uses four repetitions to build the callback table
        // later invoked by JSR (A4).  Arbitrary LEAs are deliberately ignored:
        // most point at rectangles and other inline data.
        if ((opcode & 0xf1ff) != 0x41fa || !readableWord(memory, address.add(4))) return;
        int register = (opcode >> 9) & 7;
        int store = unsignedWord(memory, address.add(4));
        if ((store & 0xf1f8) != 0x20c8 || (store & 7) != register) return;
        int displacement = (short)unsignedWord(memory, address.add(2));
        addCandidate(candidates, address.add(2).add(displacement), memory);
    }

    @Override
    public void run() throws Exception {
        String[] args = getScriptArgs();
        String programName = currentProgram.getName();
        String output = args.length > 0 ? args[0] : programName + "_traps.csv";
        String namesPath = args.length > 1 ? args[1] : null;

        Map<Integer, String> exactNames = new HashMap<>();
        Map<Integer, String> namesByNumber = new HashMap<>();
        loadNames(namesPath, exactNames, namesByNumber);

        Listing listing = currentProgram.getListing();
        Memory memory = currentProgram.getMemory();
        TreeMap<Long, TrapSite> sites = new TreeMap<>();

        ArrayDeque<Address> candidates = new ArrayDeque<>();
        Set<Long> visited = new HashSet<>();

        // Extracted CODE resources begin with the four-byte Segment Loader
        // header; the first routine starts at +4.
        Address segmentEntry = memory.getMinAddress();
        if (programName.startsWith("CODE_") && segmentEntry != null)
            segmentEntry = segmentEntry.add(4);
        addCandidate(candidates, segmentEntry, memory);

        // MarkEntries creates USER_DEFINED functions from CODE 0's export list.
        // Do not seed Ghidra's ANALYSIS functions: its function-start heuristic
        // also finds instruction-shaped inline data, which would poison the map.
        currentProgram.getFunctionManager().getFunctions(true).forEachRemaining(function -> {
            SourceType source = function.getSymbol().getSource();
            if (source != SourceType.ANALYSIS && source != SourceType.DEFAULT)
                addCandidate(candidates, function.getEntryPoint(), memory);
        });

        while (!candidates.isEmpty()) {
            monitor.checkCancelled();
            Address address = candidates.removeFirst();
            if (!visited.add(address.getOffset())) continue;

            int word = unsignedWord(memory, address);
            if ((word & 0xf000) == 0xa000) {
                sites.putIfAbsent(address.getOffset(), new TrapSite(address, word));
                addCandidate(candidates, address.add(2), memory);
                continue;
            }

            Instruction instruction = listing.getInstructionAt(address);
            if (instruction == null) {
                // Raw segments are imported at address 0, the same numeric
                // range as Macintosh low memory. Data-reference analysis can
                // therefore define a low-memory target (for example $016A)
                // on top of code at the same segment offset. A trusted flow
                // edge wins over that heuristic data unit.
                CodeUnit obstruction = listing.getCodeUnitContaining(address);
                if (obstruction != null && !(obstruction instanceof Instruction))
                    clearListing(obstruction.getMinAddress(), obstruction.getMaxAddress());
                disassemble(address);
                instruction = listing.getInstructionAt(address);
            }
            if (instruction == null) continue;
            addStoredPcRelativeRoutine(candidates, instruction, memory);
            addCandidate(candidates, instruction.getFallThrough(), memory);
            // A5-relative JSRs are calls through CODE 0's jump table. Ghidra
            // cannot resolve the destination and consequently supplies no
            // fall-through, but the Segment Loader ABI still returns to the
            // next instruction. Without this edge the Intro walk stops before
            // its Button loop at +$0224.
            if (instruction.getFallThrough() == null && instruction.getFlowType().isCall())
                addCandidate(candidates, instruction.getMaxAddress().add(1), memory);
            for (Address flow : instruction.getFlows()) addCandidate(candidates, flow, memory);
        }

        Matcher segmentMatch = SEGMENT_ID.matcher(programName);
        String segment = segmentMatch.find()
            ? Integer.toString(Integer.parseInt(segmentMatch.group(1))) : programName;

        try (PrintWriter writer = new PrintWriter(new BufferedWriter(new FileWriter(output)))) {
            writer.println("segment,offset,word,base,class,routine,flags,function");
            for (TrapSite site : sites.values()) {
                int number = trapNumber(site.word);
                String name = exactNames.get(site.word);
                if (name == null) name = namesByNumber.get(number);
                if (name == null) name = unknownName(site.word);
                Function function = getFunctionContaining(site.address);
                if (function == null) {
                    Instruction previous = listing.getInstructionBefore(site.address);
                    if (previous != null && site.address.equals(previous.getFallThrough()))
                        function = getFunctionContaining(previous.getAddress());
                }
                writer.printf("%s,0x%04X,0x%04X,0x%04X,%s,%s,%s,%s%n",
                    segment, site.address.getOffset(), site.word, baseWord(site.word),
                    (site.word & 0x0800) != 0 ? "Toolbox" : "OS",
                    name, flags(site.word), function != null ? function.getName() : "");
            }
        }
        println("DumpTraps: wrote " + sites.size() + " sites from " + programName
            + " after visiting " + visited.size() + " reachable boundaries to " + output
            + " (" + exactNames.size() + " trap names loaded)");
    }
}
