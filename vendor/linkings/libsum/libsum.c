extern int add(int a, int b);

int sum(int n)
{
  int result = 0;
  for (int i = 1; i <= n; ++i)
  {
    result = add(result, i);
  }
  return result;
}