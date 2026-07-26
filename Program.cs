using Qt.Quick;

namespace DeskAlert;

public class Program
{
    internal static void Main(string[] args)
    {
        Config.LoadConfig();

        Qml.LoadFromRootModule("Main");
        Qml.WaitForExit();
    }
}
