import java.util.Scanner;
class reverse {
    public static void main(String[] args) {
        Scanner s = new Scanner(System.in);
        System.out.println("enter limit");
        int n = s.nextInt();
        int a[] = new int [n];
        System.out.println("enter " + n + "values");
        for( int i=0; i<n; i++) {
            a[i] = s.nextInt();
        }
        int left = 0;
        int right = a.length - 1;
        while (left < right) {
            int temp = a[left];
            a[left] = a[right];
            a[right] = temp;
            left++;
            right--;
        }
        for( int i=0; i<n; i++) {
        System.out.print(a[i]);
        }
    }
}