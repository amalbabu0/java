class second{
    public static void main(String [] args) {
        int a[] = {-5,2,3,4,1,6};
        int l = a[0];
        int sl = a[0];
        for(int i=0;i<a.length-1;i++) {
                if (l<a[i]) {
                    l = a[i];
                }
        }
        for(int i=0;i<a.length-1;i++) {
                if (sl<a[i] && sl<l) {
                    sl = a[i];
                }
        }
        System.out.println(sl);
    }
}


