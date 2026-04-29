import java.util.Scanner;
class binary_search {
    public static void main(String[] args) {
        Scanner s = new Scanner(System.in);
        System.out.println("enter");
        int n = s.nextInt();
        int a[] = { 1,3,5,7,9,10};
        int st = 0;
        int ls = a.length - 1;
        while (st<=ls) {
            int mid = (st + ls) / 2;
            if (a[mid] == n) {
                System.out.println("found at" + mid);
                break;
            } else if (a[mid] < n) {
                st = mid + 1;
            } else {
                ls = mid - 1;
            }
        }
    }
}