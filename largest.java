import java.util.Scanner;
class largest{
    public static void main(String[] args) {
        Scanner s = new Scanner(System.in);
        System.out.println("enter");
        int a = s.nextInt(), b = s.nextInt(), c = s.nextInt();
        System.out.println(Math.max(a, Math.max(b,c)));
    }
}