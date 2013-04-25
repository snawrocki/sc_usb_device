/*
 * @brief Implements endpoint zero for an HID device.
 */

#include <xs1.h>
#include "usb_device.h"
#include "hid.h"

/* TODO
 * current config doesn't get reset on bus reset
 */

#define BCD_DEVICE   0x1000
#define VENDOR_ID    0x20B1
#define PRODUCT_ID   0x1010

/* Device Descriptor */
static unsigned char devDesc[] = 
{ 
    0x12,                  /* 0  bLength */
    DEVICE,                /* 1  bdescriptorType */ 
    0x00,                  /* 2  bcdUSB */ 
    0x02,                  /* 3  bcdUSB */ 
    0x00,                  /* 4  bDeviceClass */ 
    0x00,                  /* 5  bDeviceSubClass */ 
    0x00,                  /* 6  bDeviceProtocol */ 
    0x40,                  /* 7  bMaxPacketSize */ 
    (VENDOR_ID & 0xFF),    /* 8  idVendor */ 
    (VENDOR_ID >> 8),      /* 9  idVendor */ 
    (PRODUCT_ID & 0xFF),   /* 10 idProduct */ 
    (PRODUCT_ID >> 8),     /* 11 idProduct */ 
    (BCD_DEVICE & 0xFF),   /* 12 bcdDevice */
    (BCD_DEVICE >> 8),     /* 13 bcdDevice */
    0x01,                  /* 14 iManufacturer */
    0x02,                  /* 15 iProduct */
    0x00,                  /* 16 iSerialNumber */
    0x01                   /* 17 bNumConfigurations */
};


/* Configuration Descriptor */
static unsigned char cfgDesc[] = {  
  0x09,                 /* 0  bLength */ 
  0x02,                 /* 1  bDescriptortype */ 
  0x22, 0x00,           /* 2  wTotalLength */ 
  0x01,                 /* 4  bNumInterfaces */ 
  0x01,                 /* 5  bConfigurationValue */
  0x04,                 /* 6  iConfiguration */
  0x80,                 /* 7  bmAttributes */ 
  0xC8,                 /* 8  bMaxPower */
  
  0x09,                 /* 0  bLength */
  0x04,                 /* 1  bDescriptorType */ 
  0x00,                 /* 2  bInterfacecNumber */
  0x00,                 /* 3  bAlternateSetting */
  0x01,                 /* 4: bNumEndpoints */
  0x03,                 /* 5: bInterfaceClass */ 
  0x00,                 /* 6: bInterfaceSubClass */ 
  0x02,                 /* 7: bInterfaceProtocol*/ 
  0x00,                 /* 8  iInterface */ 
  
  0x09,                 /* 0  bLength. Note this is currently
                              replicated in hidDescriptor[] below */ 
  0x21,                 /* 1  bDescriptorType (HID) */ 
  0x10,                 /* 2  bcdHID */ 
  0x11,                 /* 3  bcdHID */ 
  0x00,                 /* 4  bCountryCode */ 
  0x01,                 /* 5  bNumDescriptors */ 
  0x22,                 /* 6  bDescriptorType[0] (Report) */ 
  0x48,                 /* 7  wDescriptorLength */ 
  0x00,                 /* 8  wDescriptorLength */ 
  
  0x07,                 /* 0  bLength */ 
  0x05,                 /* 1  bDescriptorType */ 
  0x81,                 /* 2  bEndpointAddress */ 
  0x03,                 /* 3  bmAttributes */ 
  0x40,                 /* 4  wMaxPacketSize */ 
  0x00,                 /* 5  wMaxPacketSize */ 
  0x01                  /* 6  bInterval */ 
}; 

static unsigned char hidDescriptor[] = 
{  
    0x09,               /* 0  bLength */ 
    0x21,               /* 1  bDescriptorType (HID) */ 
    0x10,               /* 2  bcdHID */ 
    0x11,               /* 3  bcdHID */ 
    0x00,               /* 4  bCountryCode */ 
    0x01,               /* 5  bNumDescriptors */ 
    0x22,               /* 6  bDescriptorType[0] (Report) */ 
    0x48,               /* 7  wDescriptorLength */ 
    0x00,               /* 8  wDescriptorLength */ 
};
#define NUM_EP_OUT 1
#define NUM_EP_IN 2


/* String table */
static unsigned char stringDescriptors[][40] = 
{
    "\\004\\009",               // Language string
    "XMOS",                     // iManufacturer 
    "Example HID Mouse",        // iProduct
    "",                         // unUsed
    "Config",                   // iConfiguration
};

/* HID Report Descriptor */
static unsigned char hidReportDescriptor[] = 
{
    0x05, 0x01,   // Usage page (desktop)
    0x09, 0x02,   // Usage (mouse)
    0xA1, 0x01,   // Collection (app)
    0x05, 0x09,   // Usage page (buttons)
    0x19, 0x01, 
    0x29, 0x03,
    0x15, 0x00,   // Logical min (0)
    0x25, 0x01,   // Logical max (1)
    0x95, 0x03,   // Report count (3)
    0x75, 0x01,   // Report size (1)
    0x81, 0x02,   // Input (Data, Absolute)
    0x95, 0x01,   // Report count (1)
    0x75, 0x05,   // Report size (5)
    0x81, 0x03,   // Input (Absolute, Constant)
    0x05, 0x01,   // Usage page (desktop)
    0x09, 0x01,   // Usage (pointer)
    0xA1, 0x00,   // Collection (phys)
    0x09, 0x30,   // Usage (x)
    0x09, 0x31,   // Usage (y)
    0x15, 0x81,   // Logical min (-127)
    0x25, 0x7F,   // Logical max (127)
    0x75, 0x08,   // Report size (8)
    0x95, 0x02,   // Report count (2)
#ifdef ADC
    0x81, 0x02,   // Input (Data, Abs) 0x2 to 0x6 for Rel
#else
    0x81, 0x06,
#endif
    0xC0,         // End collection
    0x09, 0x38,   // Usage (Wheel)
    0x95, 0x01,   // Report count (1)
    0x81, 0x02,   // Input (Data, Relative)
    0x09, 0x3C,   // Usage (Motion Wakeup)
    0x15, 0x00,   // Logical min (0)
    0x25, 0x01,   // Logical max (1)
    0x75, 0x01,   // Report size (1)
    0x95, 0x01,   // Report count (1)
    0xB1, 0x22,   // Feature (No preferred, Variable)
    0x95, 0x07,   // Report count (7)
    0xB1, 0x01,   // Feature (Constant)
    0xC0          // End collection
};

/* HID Class Requests */
int HidInterfaceClassRequests(XUD_ep c_ep0_out, XUD_ep c_ep0_in,
        USB_SetupPacket_t sp)
{
    unsigned char buffer[64];
    unsigned tmp;

    switch(sp.bRequest)
    { 
        case GET_REPORT:        
        
            /* Mandatory. Allows sending of report over control pipe */
            /* Send a hid report - note the use of asm due to shared mem */
            asm("ldaw %0, dp[g_reportBuffer]": "=r"(tmp));
            asm("ldw %0, %1[0]": "=r"(tmp) : "r"(tmp));
            (buffer, unsigned[])[0] = tmp;

            return XUD_DoGetRequest(c_ep0_out, c_ep0_in,
                        buffer, 4, sp.wLength);
            break;

        case GET_IDLE:
            /* Return the current Idle rate - optional for a HID mouse */

            /* Do nothing - i.e. STALL */
            break;

        case GET_PROTOCOL:      
            /* Required only devices supporting boot protocol devices,
             * which this example does not */

            /* Do nothing - i.e. STALL */
            break;

         case SET_REPORT: 
            /* The host sends an Output or Feature report to a HID
             * using a cntrol transfer - optional */

            /* Do nothing - i.e. STALL */
            break;

        case SET_IDLE:      
            /* Set the current Idle rate - this is optional for a HID mouse 
             * (Bandwidth can be saved by limiting the frequency that an
             * interrupt IN EP when the data hasn't changed since the last
             * report */

            /* Do nothing - i.e. STALL */
            break;
            
        case SET_PROTOCOL:     
            /* Required only devices supporting boot protocol devices,
             * which this example does not */

            /* Do nothing - i.e. STALL */
            break;
    }

    return 1;
}

/* Endpoint 0 Task */
void Endpoint0(chanend chan_ep0_out, chanend chan_ep0_in, chanend ?c_usb_test)
{
    USB_SetupPacket_t sp;

    unsigned bmRequestType; 
    XUD_BusSpeed usbBusSpeed;
    
    XUD_ep ep0_out = XUD_InitEp(chan_ep0_out);
    XUD_ep ep0_in  = XUD_InitEp(chan_ep0_in);
    
    while(1)
    {
        /* Returns 0 on success, < 0 for USB RESET */
        int retVal = USB_GetSetupPacket(ep0_out, ep0_in, sp);
        
        if(!retVal) 
        {
            /* Stick bmRequest type back together for an easier parse... */
            bmRequestType = (sp.bmRequestType.Direction<<7) |
                            (sp.bmRequestType.Type<<5) |
                            (sp.bmRequestType.Recipient);
    
            switch(bmRequestType)
            {
                case BMREQ_D2H_STANDARD_INT:
 
                    if(sp.bRequest == GET_DESCRIPTOR)
                    {
                        /* HID Interface is Interface 0 */
                        if(sp.wIndex == 0)
                        {
                            /* Look at Descriptor Type (high-byte of wValue) */ 
                            unsigned short descriptorType = sp.wValue & 0xff00;
            
                            switch(descriptorType)
                            {
                                case HID:
                                    retVal = XUD_DoGetRequest(ep0_out, ep0_in, hidDescriptor, 
                                        sizeof(hidDescriptor), sp.wLength);
                                    break;
                        
                                case REPORT:
                                    retVal = XUD_DoGetRequest(ep0_out, ep0_in, hidReportDescriptor,
                                        sizeof(hidReportDescriptor), sp.wLength);
                                    break;
                            }
                        }
                    }
                    break;

                case BMREQ_H2D_CLASS_INT:
                case BMREQ_D2H_CLASS_INT:

                    /* Inspect for HID interface num */
                    if(sp.wIndex == 0)
                    {
                        /* Returns  0 if handled, 
                         *          1 if not handled,
                         *         -1 for bus reset */
                        retVal = HidInterfaceClassRequests(ep0_out,
                                    ep0_in, sp);
                    }
                    break;
            }
        }

        /* If we havn't handled the request about, 
         * then do standard enumeration requests  */
        if(!retVal)
        {
            /* Returns  0 if handled okay,
             *          1 if request was not handled (STALLed),
             *         -1 of USB Reset */
            retVal = USB_StandardRequests(ep0_out, ep0_in, devDesc,
                        sizeof(devDesc), cfgDesc, sizeof(cfgDesc),
                        null, 0, null, 0, stringDescriptors, sp,
                        c_usb_test, usbBusSpeed);
        }

        /* USB bus reset detected, reset EP and get new bus speed */
        if(retVal < 0)
        {
            usbBusSpeed = XUD_ResetEndpoint(ep0_out, ep0_in);
        }
    }
}
//: 


 




