DECLARE
  TYPE obj_arr IS TABLE OF VARCHAR2(300);
  DRP_STMT VARCHAR2(4000) := 'drop ';
  obj_list obj_arr := obj_arr('public synonym json_dyn');
BEGIN
  FOR I IN OBJ_LIST.FIRST..OBJ_LIST.LAST LOOP
  begin
    EXECUTE IMMEDIATE DRP_STMT||OBJ_LIST(I);
  EXCEPTION WHEN OTHERS THEN
    NULL;
  end;
  end loop;
END;
/
create or replace package json_dyn wrapped 
a000000
1
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
9
af df
CJrmdEhfhcGl9mdJ8wW822Jmercwgy7wLcsVfC+EWPiUHDX824Mp7HagbNdcnJkJsFZZdAFw
Bru9S3BCLYFWll3R9cloT9A7aIf9FgV8I1PYl7Py3NgOdyFngVEGtBcBFF7orV/6M9FaDzYL
RpGEjknZGK4xKyffcaFVZyN+s9CzsUY+oVYlrorYBHpPFgdFR6h2RbvrT1eSLLuxtM0ZYKdW
iA==

/
show errors
grant execute on json_dyn to public
/
create or replace public synonym json_dyn for PC.json_dyn
/
create or replace package body json_dyn wrapped 
a000000
1
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
b
90d 477
gcGEXB8jOSw1C/fcel6s6boGc7owgw3DBUrrfC9DQp3gGfFaMRED0LpnwPHeHpXw1s2KCS8Y
L469NmJ+mNPVzcaCn9HcMxXprCKigV/BzkdDWZWbH343yPrgsk/+mHlO7smZWSyk+8Pyi1R3
GDQ0VuzHYtlpIUI7DtjqiOW0MZZ14R4nkZ9Kvt5ZkWo3P5a4YlPfO5zL8NqQAB5q8USr9rGC
RUHurJzRftGUuI9sGsgUAFrx2UUhyhrYaGymIijGV8lMOLRMy0KOr4Ln9f82XjU2yfQBHzlp
kdVVfZxmUpPMehdY3d8DBKwDjzM8htsLwvXcX36gzDRxogPL8wL5HdFZPmG8gETHZuNqiI9R
LWdB7zWLDOjc/Quh/xt4vdODBnuli4d5kEJZ28b4wMQkutLHutK3FFKFy2dOsQRguFk7BFw/
RyF60IoKYKiC7i8RO1maiJkPRVKrWjGjii15g2vfbcaD6yUEAWCpjP+Ptfba88FOMyHcFfks
0mUDe+xaoQUJO2iCvsiT73mzAXkOib7YPHDwf1WjiH0StdqQ8CqtHlYC+kauvmeQBb387a2h
3iMP/cknAH/TclEt9XawPIsifkOgtBkNVb+7UKS6VjdDFVaYaFEmwqEbTIrHV95jjwsmRQrR
Vhu7RxJpf/DWCunKtVP7eb0jxd8Bkzje8KOfKXRBGD4A0lVvezO88Yg/N0zQ7eU3Xt4aLpPj
Sv6QjVfSfcstoZmOckv6Y03qY7lqcYIG4gtqai9hLiOSdiUp/2lf9n5UXL1BtpPsW8Py5Rmk
HE9BGkk+svWdR7dz7idOuQrOoCTdi8bE1/hqix2KYf0wnfjAczKZ6hNzgZwdz2hMr/4e1z3X
iMjTfpNmJAUQ32J/2SFZ76P6FTt7xmUAcwd62icHEyD9zqAHzbmPyaUcDVuBTI9unBCQmGWw
CHzXKBoqX7UwqaWUiw0pOWzA5jkkt5wY/RqK5+hPRyHLGTZ3P5aJ2Wwf52vGboz6nPDxnEz4
79U249TZPQpKhTY1nXk5499igw9R1IC3+CqzW138+/nTbfFK1n35b3aCb/Eba40Gade9uVSS
0LvxhtJIaGrPGdwTfDpUGD8dckqKMWI94Ez/QeQ2FYY1Ng==

/
show errors
exit
