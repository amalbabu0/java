import java.util.Scanner;
class lcm {
    public static void main(String[] args) {
        Scanner s = new Scanner(System.in);
        int a = s.nextInt();
        int b = s.nextInt();
        int max = Math.max(a,b);
        int lcm = max;
        while(lcm%a != 0 || lcm%b != 0 ) {
            lcm = lcm + max;
        }
        System.out.println(lcm);
    }
}