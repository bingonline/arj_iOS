//
//  Tcp.h
//  arj
//
//  Created by ice ma on 2018/1/12.
//  Copyright © 2018年 Esterel Technologies. All rights reserved.
//

#ifndef Tcp_h
#define Tcp_h

#include <stdio.h>

typedef struct
{
    float data1;
    float data2;
    float data3;
}ICDData;

extern ICDData the_icd_data;

void TcpRecv();
#endif /* Tcp_h */
