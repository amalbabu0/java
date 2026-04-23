import java.util.Scanner;
class oddoreven{
    public static void main(String[] args) {
        Scanner s =new Scanner(System.in);
        System.out.println("enter");
        int a = s.nextInt();
        switch(a % 2) {
            case 0 -> System.out.println("even");
            default -> System.out.println("odd");
        }
    }
}