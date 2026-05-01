class selection_sort {
    public static void main (String[] args) {
        int a[] = { 2,4,1,2,6,3,8,9,3}; 
        for(int i=0; i<a.length-1; i++) {
            int min = i;
            for(int j = i+1; j<a.length;j++){
                if(a[j] < a[min]) {
                    min = j;
                }
            }
            for(int c=0; c<a.length; c++) {
                System.out.print(a[c]);
            }
            System.out.println();
            int temp = a[min];
            a[min] = a[i];
            a[i] = temp;
        }
        for(int i=0; i<a.length-1; i++) {
            System.out.print(a[i]);
        }
    }
 }