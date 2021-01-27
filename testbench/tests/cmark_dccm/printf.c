#include <stdarg.h>

// This should be in some .h file.
#define STDOUT 0xd0580000

static int
whisperPutc(char c)
{
//  __whisper_console_io = c;
//  __whisper_console_io = c;
  *(volatile char*)(STDOUT) = c;
  return c;
}


static int
whisperPuts(const char* s)
{
  while (*s)
    whisperPutc(*s++);
  return 1;
}


static int
whisperPrintDecimal(int value)
{
  char buffer[20];
  int charCount = 0;

  unsigned neg = value < 0;
  if (neg)
    {
      value = -value;
      whisperPutc('-');
    }

  do
    {
      char c = '0' + (value % 10);
      value = value / 10;
      buffer[charCount++] = c;
    }
  while (value);

  char* p = buffer + charCount - 1;
  for (unsigned i = 0; i < charCount; ++i)
    whisperPutc(*p--);

  if (neg)
    charCount++;

  return charCount;
}


static int
whisperPrintInt(int value, int base)
{
  if (base == 10)
    return whisperPrintDecimal(value);

  char buffer[20];
  int charCount = 0;

  unsigned uu = value;

  if (base == 8)
    {
      do
        {
          char c = '0' + (uu & 7);
          buffer[charCount++] = c;
          uu >>= 3;
        }
      while (uu);
    }
  else if (base == 16)
    {
      do
        {
          int digit = uu & 0xf;
          char c = digit < 10 ? '0' + digit : 'a' + digit - 10;
          buffer[charCount++] = c;
          uu >>= 4;
        }
      while (uu);
    }
  else
    return -1;

  char* p = buffer + charCount - 1;
  for (unsigned i = 0; i < charCount; ++i)
    whisperPutc(*p--);

  return charCount;
}


int
whisperPrintfImpl(const char* format, va_list ap)
{
  int count = 0;  // Printed character count

  for (const char* fp = format; *fp; fp++)
    {
      if (*fp != '%')
        {
          whisperPutc(*fp);
          ++count;
          continue;
        }

      ++fp;  // Skip %

      if (*fp == 0)
        break;

      if (*fp == '%')
        {
          whisperPutc('%');
          continue;
        }

      if (*fp == '-')
        {
          fp++;  // Pad right not yet implemented.
        }

      while (*fp == '0')
        {
          fp++;  // Pad zero not yet implented.
        }

      if (*fp == '*')
        {
          int width = va_arg(ap, int);
          fp++;  // Width not yet implemented.
        }
      else
        {
          while (*fp >= '0' && *fp <= '9')
            ++fp;   // Width not yet implemented.
        }

      switch (*fp)
        {
        case 'd':
          count += whisperPrintDecimal(va_arg(ap, int));
          break;

        case 'u':
          count += whisperPrintDecimal((unsigned) va_arg(ap, unsigned));
          break;

        case 'x':
        case 'X':
          count += whisperPrintInt(va_arg(ap, int), 16);
          break;

        case 'o':
          count += whisperPrintInt(va_arg(ap, int), 8);
          break;

        case 'c':
          whisperPutc(va_arg(ap, int));
          ++count;
          break;

        case 's':
          count += whisperPuts(va_arg(ap, char*));
          break;
        }
    }

  return count;
}


int
whisperPrintf(const char* format, ...)
{
  va_list ap;

  va_start(ap, format);
  int code = whisperPrintfImpl(format, ap);
  va_end(ap);

  return code;
}

