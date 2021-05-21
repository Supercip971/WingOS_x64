#include "stivale.h"
#include <stddef.h>
#define STACK_SIZE 16000
char stack[STACK_SIZE * 4] __attribute__((aligned(16))) = {0};
struct stivale2_header_tag_framebuffer framebuffer_hdr_tag = {
    .tag = {
        .identifier = STIVALE2_HEADER_TAG_FRAMEBUFFER_ID,
        .next = 0},
    .framebuffer_width = 1440,
    .framebuffer_height = 900,
    .framebuffer_bpp = 32};

__attribute__((section(".stivale2hdr"), used)) struct stivale2_header stivale_hdr = {
    .entry_point = 0,
    .stack = (uintptr_t)stack + sizeof(stack),
    .flags = 0b0,
    .tags = (uintptr_t)&framebuffer_hdr_tag};

struct stivale2_struct boot_loader_data_copy;

stivale2_struct_tag_framebuffer tag_framebuffer_copy;

stivale2_tag *stivale2_find_tag(uint64_t tag_id)
{
    stivale2_tag *current = (stivale2_tag *)boot_loader_data_copy.tags;
    while (current != NULL)
    {
        if (current->identifier == tag_id)
        {
            return current;
        }

        current = (stivale2_tag *)current->next;
    }
    return NULL;
}

extern "C" void kernel_start(void *bootloader_data)
{

    while (true)
    {
    }
}