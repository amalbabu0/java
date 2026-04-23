import java.util.Scanner;
class print_1_n {
    public static void main(String[] args) {
        Scanner s = new Scanner(System.in);
        int n = s.nextInt();
        int a = 1;
        while (a<=n){
            System.out.println(a);
            a++;
        }
    }
}