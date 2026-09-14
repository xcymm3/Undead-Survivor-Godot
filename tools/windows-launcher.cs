using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Reflection;
using System.Text;
using System.Windows.Forms;

// Compiled as a Windows application: double-clicking never opens a console.
internal static class WindowsLauncher
{
    // Windows command-line quoting, including empty arguments and trailing slashes.
    private static string Quote(string value)
    {
        var result = new StringBuilder("\"");
        int slashes = 0;
        foreach (char c in value)
        {
            if (c == '\\') { slashes++; continue; }
            result.Append('\\', c == '"' ? slashes * 2 + 1 : slashes);
            result.Append(c);
            slashes = 0;
        }
        result.Append('\\', slashes * 2);
        return result.Append('"').ToString();
    }

    [STAThread]
    private static int Main(string[] args)
    {
        bool headless = args.Contains("--headless");
        string directory = Path.Combine(Path.GetTempPath(), "Undead-Survivor-Godot", Guid.NewGuid().ToString("N"));
        try
        {
            Directory.CreateDirectory(directory);
            using (Stream payload = Assembly.GetExecutingAssembly().GetManifestResourceStream("game.zip"))
            using (var archive = new ZipArchive(payload, ZipArchiveMode.Read))
            {
                foreach (ZipArchiveEntry entry in archive.Entries)
                {
                    // The build only embeds flat files; reject paths in malformed payloads.
                    if (entry.FullName != Path.GetFileName(entry.FullName) || entry.FullName.Contains(":"))
                        throw new InvalidDataException("Invalid embedded file name.");
                    entry.ExtractToFile(Path.Combine(directory, entry.FullName));
                }
            }
            var start = new ProcessStartInfo
            {
                FileName = Path.Combine(directory, "Undead-Survivor-Godot.exe"),
                WorkingDirectory = directory,
                Arguments = String.Join(" ", args.Select(Quote)),
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardOutput = true,
                RedirectStandardError = true
            };
            using (var child = new Process { StartInfo = start })
            {
                child.OutputDataReceived += (sender, e) => { if (e.Data != null) Console.Out.WriteLine(e.Data); };
                child.ErrorDataReceived += (sender, e) => { if (e.Data != null) Console.Error.WriteLine(e.Data); };
                child.Start();
                child.BeginOutputReadLine();
                child.BeginErrorReadLine();
                child.WaitForExit();
                return child.ExitCode;
            }
        }
        catch (Exception error)
        {
            Console.Error.WriteLine("Single-file launcher failed: " + error);
            if (!headless)
                MessageBox.Show("游戏启动失败：\n" + error.Message, "Undead Survivor", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }
        finally
        {
            // Only our own unique extraction directory; never touch saves or other instances.
            try { if (Directory.Exists(directory)) Directory.Delete(directory, true); }
            catch (IOException) { }
            catch (UnauthorizedAccessException) { }
        }
    }
}
