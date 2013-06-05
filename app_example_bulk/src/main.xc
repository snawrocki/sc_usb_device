/**
 * The copyrights, all other intellectual and industrial 
 * property rights are retained by XMOS and/or its licensors. 
 * Terms and conditions covering the use of this code can
 * be found in the Xmos End User License Agreement.
 *
 * Copyright XMOS Ltd 2013
 *
 * In the case where this code is a modification of existing code
 * under a separate license, the separate license terms are shown
 * below. The modifications to the code are still covered by the 
 * copyright notice above.
 *
 **/ 

#include <platform.h>
#include <stdio.h>

#include "xud.h"
#include "usb.h"

#define XUD_EP_COUNT_OUT   2
#define XUD_EP_COUNT_IN    2

/* Prototype for Endpoint0 function in endpoint0.xc */
void Endpoint0(chanend c_ep0_out, chanend c_ep0_in, chanend ?c_usb_test);

/* Endpoint type tables - infoms XUD what the transfer types for each Endpoint in use and also
 * if the endpoint wishes to be informed of USB bus resets 
 */
XUD_EpType epTypeTableOut[XUD_EP_COUNT_OUT] = {XUD_EPTYPE_CTL | XUD_STATUS_ENABLE, XUD_EPTYPE_BUL | XUD_STATUS_ENABLE};
XUD_EpType epTypeTableIn[XUD_EP_COUNT_IN] =   {XUD_EPTYPE_CTL | XUD_STATUS_ENABLE, XUD_EPTYPE_BUL | XUD_STATUS_ENABLE};

#if (XUD_SERIES_SUPPORT == XUD_U_SERIES)
  /* USB Reset not required for U series - pass null to XUD */
  #define p_usb_rst null
  #define clk_usb_rst null
#else
  /* USB reset port de_usb_clarations for L series on L1 USB Audio board */
  on USB_TILE: out port p_usb_rst   = XS1_PORT_32A;
  on USB_TILE: clock    clk_usb_rst = XS1_CLKBLK_3;
#endif

#define BUFFER_SIZE 128
void bulk_endpoint(chanend chan_ep_from_host, chanend chan_ep_to_host) 
{
    int host_transfer_buf[BUFFER_SIZE];
    int host_transfer_length = 0;

    XUD_ep ep_from_host = XUD_InitEp(chan_ep_from_host);
    XUD_ep ep_to_host = XUD_InitEp(chan_ep_to_host);

    while(1) 
    {
        host_transfer_length = XUD_GetBuffer(ep_from_host, (host_transfer_buf, char[BUFFER_SIZE * 4]));
        if (host_transfer_length < 0) {
            XUD_ResetEndpoint(ep_from_host, ep_to_host);
            continue;
        }

        for (int i = 0; i < host_transfer_length/4; i++)
            host_transfer_buf[i]++;

        host_transfer_length = XUD_SetBuffer(ep_to_host, (host_transfer_buf, char[BUFFER_SIZE * 4]), host_transfer_length);
        if (host_transfer_length < 0)
            XUD_ResetEndpoint(ep_from_host, ep_to_host);
    }
}

/*
 * The main function runs three tasks: the XUD manager, Endpoint 0, and bulk endpoint. An array of
 * channels is used for both IN and OUT endpoints, endpoint zero requires both, buly requires an IN 
 * and an OUT endpoint to receive and send a data buffer to the host.
 */
int main() 
{
    chan c_ep_out[XUD_EP_COUNT_OUT], c_ep_in[XUD_EP_COUNT_IN];

    par 
    {
        on USB_TILE: XUD_Manager(c_ep_out, XUD_EP_COUNT_OUT, c_ep_in, XUD_EP_COUNT_IN,
                                   null, epTypeTableOut, epTypeTableIn,
                                   p_usb_rst, clk_usb_rst, -1, XUD_SPEED_HS, null); 

        on USB_TILE: Endpoint0(c_ep_out[0], c_ep_in[0], null);
       
        on USB_TILE: bulk_endpoint(c_ep_out[1], c_ep_in[1]);
    }

    return 0;
}
