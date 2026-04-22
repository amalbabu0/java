import java.util.Scanner;
class palChar {
    public static void main(String[] args) {
        Scanner s = new Scanner(System.in);
        String a = s.nextLine().toLowerCase();
        String rev = "";
        for(int i = 0; i< a.length(); i++) {
            rev = a.charAt(i) + rev;
        }
        System.out.println(rev);
        if (a.equals(rev)) {
            System.out.println("yes");
        } else {
            System.out.println("no");
        }
    }
}