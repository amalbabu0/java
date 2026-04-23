import java.io.File;
import java.io.FileWriter;
import java.io.FileReader;
public class file {
    public static void main(String[] args) {
        String a = "asdfghjkl";
        char b[] = new char[50];
        try {
            // Create a File object representing "a.txt" in the current directory
            File f = new File("a.txt");
            // Try to create the file on disk; if it doesn't exist, it is created
            boolean sus = f.createNewFile();
            // Open a FileWriter to write into "a.txt"
            FileWriter fw = new FileWriter("a.txt");
            // Write the string `a` into the file
            fw.write(a);
            // Close the FileWriter so the data is flushed to disk and the file is released
            fw.close();
            // Open a FileReader to read content from "a.txt"
            FileReader fr = new FileReader("a.txt");
            // Read up to 50 characters from the file into the char array `b`
            fr.read(b);
            // Close the FileReader to release the file
            fr.close();
            System.out.println(b);
        } catch (Exception ex) {
            System.out.println("no");
        }
    }
}