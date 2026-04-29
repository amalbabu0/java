import java.util.Scanner;
class even_odd{
    public static void main(String[] args){
        Scanner s = new Scanner(System.in);
        System.out.println("enter");
        int n = s.nextInt();
        int a[] = new int[n];
        for(int i = 0; i<n; i++) {
            a[i] = s.nextInt();
        }
        int odd = 0;
        int even = 0;
        for(int i = 0; i<n; i++) {
            if (a[i]%2 == 0) {
                even++;
            } else {
                odd++;
            }
        }
        System.out.println("even :" + even + " ,odd :" + odd);
    }
}