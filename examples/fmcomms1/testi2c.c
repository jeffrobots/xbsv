/* copied from jca's i2chdmi.h */

#include <linux/types.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <errno.h>
#include "/usr/include/linux/i2c.h"
#include "/usr/include/linux/i2c-dev.h"
#include <stdio.h>
#include <stdlib.h>



int fmcomms1_read_eeprom(int fd, int device, unsigned char *datap, int size)
{
  int status;
  int i;
  struct i2c_msg msgs[2];
  unsigned char command[2] = { 0, 0 };
  struct i2c_rdwr_ioctl_data arg;
  msgs[0].addr = device;
  msgs[0].flags = 0;
  msgs[0].len = 1;
  msgs[0].buf = &command[0];
  msgs[1].addr = device;
  msgs[1].flags = I2C_M_RD;
  msgs[1].len = 1;
  msgs[1].buf = datap;
  arg.msgs = msgs;
  arg.nmsgs = 1;
  datap[0] = 1;
  status = ioctl(fd, I2C_RDWR, &arg);
  if (status != 0) {
    fprintf(stderr, "[%s:%d]: ioctl I2C_RW write status=%d errno=%d\n", __FILE__, __LINE__, status, errno);
  }
  status = ioctl(fd, I2C_RDWR, &arg);
  if (status != 0) {
    fprintf(stderr, "[%s:%d]: ioctl I2C_RW write status=%d errno=%d\n", __FILE__, __LINE__, status, errno);
  }
  msgs[0] = msgs[1];
  for (i = 0; i < 16; i += 1) {
    msgs[0].buf = &datap[i];
    status = ioctl(fd, I2C_RDWR, &arg);
    if (status != 0) {
      fprintf(stderr, "[%s:%d]: loop %d ioctl I2C_RW read status=%d errno=%d\n", __FILE__, __LINE__, i, status, errno);
    }
  }
  return status;
}

int fmcomms1_get_version(int fd, int device, unsigned char *datap, int size)
{
  int status;
  struct i2c_msg msgs[2];
  unsigned char command = 1;
  struct i2c_rdwr_ioctl_data arg;
  msgs[0].addr = device;
  msgs[0].flags = 0;
  msgs[0].len = 1;
  msgs[0].buf = &command;
  msgs[1].addr = device;
  msgs[1].flags = I2C_M_RD | I2C_M_RECV_LEN;
  msgs[1].len = 33;
  msgs[1].buf = datap;
  arg.msgs = msgs;
  arg.nmsgs = 2;
  datap[0] = 1;
  status = ioctl(fd, I2C_RDWR, &arg);
  if (status != 0) {
    fprintf(stderr, "[%s:%d]: ioctl I2C_RW write status=%d errno=%d\n", __FILE__, __LINE__, status, errno);
  }
  /*
  msgs[0] = msgs[1];
  status = ioctl(fd, I2C_RDWR, &arg);
  if (status != 0) {
    fprintf(stderr, "[%s:%d]: ioctl I2C_RW read status=%d errno=%d\n", __FILE__, __LINE__, status, errno);
  }
  */
  return status;
}


unsigned char version_data[128];
int main(int argc, char *argv[])
{
   

  int fd;
    int i;
    int res;
    printf("argv[1] is %s, argv[2] is 0x%02lx\n", argv[1], strtol(argv[2], NULL, 0));
    fd = open(argv[1], O_RDWR);
    if (fd < 0) {
      printf("[%s:%d] open failed\n", __FILE__, __LINE__);
      exit(1);
    }
    // start version query
    res = fmcomms1_read_eeprom(fd, 0x50, version_data, 128);
    printf ("getversion result %d\n", res);
    for (i = 0; i < 16; i += 1) {
      if ((i != 0) && ((i % 16) == 0)) printf("\n");
      printf(" %2x", version_data[i]);
    }
    printf("\n");
    res = fmcomms1_get_version(fd, (int) strtol(argv[2], NULL, 0), version_data, 128);
    printf ("getversion result %d\n", res);
    for (i = 0; i < 32; i += 1) {
      if ((i != 0) && ((i % 16) == 0)) printf("\n");
      printf(" %2x", version_data[i]);
    }
    printf("\n");
}
