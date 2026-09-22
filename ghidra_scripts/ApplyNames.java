// Apply code names and comments from disasm/symbols.csv to the matching segment.
// A5-global and low-memory rows are documentation, not addresses in a raw CODE program.
// Arg0 = path to symbols.csv
//@category Vette
import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.*;
import ghidra.program.model.listing.*;
import ghidra.program.model.symbol.*;
import java.io.*;
import java.util.*;
import java.util.regex.*;

public class ApplyNames extends GhidraScript {
    private static final Pattern SEGMENT_ID = Pattern.compile("CODE_(\\d+)");

    @Override
    public void run() throws Exception {
        String[] args = getScriptArgs();
        String csvPath = args.length > 0 ? args[0] : "disasm/symbols.csv";

        Matcher matcher = SEGMENT_ID.matcher(currentProgram.getName());
        int currentSegment = matcher.find() ? Integer.parseInt(matcher.group(1)) : -1;
        int applied = 0, skipped = 0, otherSpace = 0;
        BufferedReader r = new BufferedReader(new FileReader(csvPath));
        String line;
        while ((line = r.readLine()) != null) {
            line = line.trim();
            if (line.isEmpty() || line.startsWith("#")) continue;
            String[] parts = line.split(",", 7);
            if (parts.length < 7 || parts[0].equals("space")) continue;
            if (!parts[0].trim().equals("code")
                    || Integer.parseInt(parts[1].trim()) != currentSegment) {
                otherSpace++;
                continue;
            }

            // Accept "$63BD", "0x63BD" and bare "63BD" — disasm/symbols.csv and
            // ghidra_scripts/entrypoints.csv both use the 0x form, and Long.parseLong(...,16)
            // rejects it, which silently skipped EVERY row (applied=0 skipped=53).
            String addrStr = parts[2].trim().replaceAll("^\\$", "").replaceAll("^0[xX]", "");
            String name    = parts[3].trim();
            String note    = "[" + parts[5].trim() + "] " + parts[6].trim();

            long offset;
            try { offset = Long.parseLong(addrStr, 16); }
            catch (NumberFormatException e) { skipped++; continue; }

            Address a = toAddr(offset);
            try {
                // Set primary label (user-source so it survives re-analysis).
                if (!name.isEmpty()) {
                    Symbol existing = getSymbolAt(a);
                    if (existing == null || existing.getSource() != SourceType.USER_DEFINED) {
                        createLabel(a, name, true, SourceType.USER_DEFINED);
                    }
                }
                // Set plate comment from note.
                if (!note.isEmpty() && note.length() > 1) {
                    CodeUnit cu = currentProgram.getListing().getCodeUnitAt(a);
                    if (cu != null) {
                        String cur = cu.getComment(CodeUnit.PLATE_COMMENT);
                        if (cur == null || cur.isEmpty())
                            cu.setComment(CodeUnit.PLATE_COMMENT, note);
                    }
                }
                applied++;
            } catch (Exception e) {
                println("SKIP " + addrStr + " (" + name + "): " + e.getMessage());
                skipped++;
            }
        }
        r.close();
        println("ApplyNames: segment=" + currentSegment + " applied=" + applied
            + " skipped=" + skipped + " non-code/other-segment=" + otherSpace);
    }
}
