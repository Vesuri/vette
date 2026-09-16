// Mark the loader/init/interrupt entry points and disassemble from each so
// auto-analysis can follow control flow.  The entry list lives in the sibling
// file entrypoints.csv (a persistent, append-only seed list) — add a line there
// whenever a new vector-only / trap-dispatched routine is found, NOT here.
//@category Vette
import java.io.BufferedReader;
import java.io.InputStreamReader;
import ghidra.app.script.GhidraScript;
import generic.jar.ResourceFile;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;

public class MarkEntries extends GhidraScript {
    @Override
    public void run() throws Exception {
        ResourceFile csv = new ResourceFile(getSourceFile().getParentFile(), "entrypoints.csv");
        if (!csv.exists()) {
            printerr("MarkEntries: entrypoints.csv not found next to the script: " + csv);
            return;
        }
        int marked = 0, skipped = 0;
        try (BufferedReader r = new BufferedReader(new InputStreamReader(csv.getInputStream()))) {
            String line;
            while ((line = r.readLine()) != null) {
                line = line.trim();
                if (line.isEmpty() || line.startsWith("#")) continue;
                int comma = line.indexOf(',');
                if (comma < 0) { printerr("MarkEntries: bad line (no comma): " + line); continue; }
                String hex  = line.substring(0, comma).trim();
                String rest = line.substring(comma + 1).trim();
                // rest is "name" or "name,note" — the note may be quoted and contain commas.
                int comma2 = rest.indexOf(',');
                String name = (comma2 < 0 ? rest : rest.substring(0, comma2)).trim();
                if (hex.equalsIgnoreCase("addr")) continue;   // the CSV header
                if (hex.startsWith("0x") || hex.startsWith("0X")) hex = hex.substring(2);
                if (hex.startsWith("$")) hex = hex.substring(1);
                long addrVal;
                try {
                    addrVal = Long.parseLong(hex, 16);
                } catch (NumberFormatException e) {
                    printerr("MarkEntries: bad address '" + hex + "' on line: " + line);
                    continue;
                }
                Address a = toAddr(addrVal);
                addEntryPoint(a);
                disassemble(a);
                Function existing = getFunctionAt(a);
                if (existing == null) {
                    createFunction(a, name);
                    println("entry: " + name + " @ " + a);
                    marked++;
                } else {
                    println("entry (exists): " + existing.getName() + " @ " + a);
                    skipped++;
                }
            }
        }
        println("MarkEntries: " + marked + " new, " + skipped + " already-present entry points.");
    }
}
