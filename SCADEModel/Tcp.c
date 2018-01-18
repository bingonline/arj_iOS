//
//  Tcp.c
//  arj
//
//  Created by ice ma on 2018/1/12.
//  Copyright © 2018年 Esterel Technologies. All rights reserved.
//

#include "Tcp.h"
#include <sys/socket.h>
#include  <netinet/in.h>
#include <arpa/inet.h>
#include <string.h>
#include <unistd.h>
int client_socket;
int success;
struct sockaddr_in addr;

ICDData the_icd_data;
int is_tcp_init=0;

int TcpInit()
{
    int error=-1;
    int addrLen=sizeof(struct sockaddr_in);
    client_socket=socket(AF_INET,SOCK_STREAM,0);
    
    if(client_socket!=-1)
    {
        memset(&addr,0,sizeof(addr));
        addr.sin_len=sizeof(addr);
        addr.sin_family=AF_INET;
        addr.sin_port=htons(8888);
        addr.sin_addr.s_addr=inet_addr("192.168.31.241");
        error=connect(client_socket,(struct sockaddr *)&addr,addrLen);
        printf("init socket succefully!\n");
        
    }
    return error;
}

void TcpRecv()
{
    if(!is_tcp_init)
    {
        TcpInit();
        is_tcp_init=1;
    }
    recv(client_socket,&the_icd_data,sizeof(ICDData),0);
}

void CloseTcp()
{
    if(is_tcp_init)
    {
         close(client_socket);
        is_tcp_init=0;
    }
   
}
