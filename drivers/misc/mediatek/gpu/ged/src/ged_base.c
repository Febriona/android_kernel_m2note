/*
 * (C) Copyright 2010
 * MediaTek <www.MediaTek.com>
 *
 * MTK GPU Extension Device
 *
 */

#include "ged_base.h"
#include <asm/page.h>
#include <linux/version.h>
#include <linux/vmalloc.h>
#include <linux/slab.h>
#include <linux/sched.h>
#include <linux/interrupt.h>

#include <asm/uaccess.h>

unsigned long ged_copy_to_user(void __user *pvTo, const void *pvFrom, unsigned long ulBytes)
{
    if (access_ok(VERIFY_WRITE, pvTo, ulBytes))
    {
    	return __copy_to_user(pvTo, pvFrom, ulBytes);
    }
    return ulBytes;
}

unsigned long ged_copy_from_user(void *pvTo, const void __user *pvFrom, unsigned long ulBytes)
{
    if (access_ok(VERIFY_READ, pvFrom, ulBytes))
    {
	    return __copy_from_user(pvTo, pvFrom, ulBytes);
    }
    return ulBytes;
}

void* ged_alloc(int i32Size)
{
    void *pvBuf;

    if (i32Size <= PAGE_SIZE)
    {
        pvBuf = kmalloc(i32Size, GFP_KERNEL);
    }
    else
    {
        pvBuf = vmalloc(i32Size);
    }

    return pvBuf;
}

void ged_free(void* pvBuf, int i32Size)
{
    if (pvBuf)
    {
        if (i32Size <= PAGE_SIZE)
        {
            kfree(pvBuf);
        }
        else
        {
            vfree(pvBuf);
        }
    }
}

long ged_get_pid(void)
{
    if (in_interrupt())
    {
        return 0xffffffffL;
    }

    return (long)task_tgid_nr(current);
}

