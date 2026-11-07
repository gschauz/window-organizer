#import "SpaceBridge.h"
#import <objc/message.h>
#import <dlfcn.h>

// Private macOS APIs are isolated here and resolved at runtime. No injection,
// security changes, hard-coded addresses, or third-party window manager required.
static void *framework(void) {
    static void *handle; static dispatch_once_t once;
    dispatch_once(&once, ^{ handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY); });
    return handle;
}
static int connection(void) {
    int (*fn)(void) = dlsym(framework(), "SLSMainConnectionID");
    return fn ? fn() : 0;
}
NSArray<NSDictionary *> *WODisplaySpaces(void) {
    CFArrayRef (*fn)(int) = dlsym(framework(), "SLSCopyManagedDisplaySpaces");
    return fn ? CFBridgingRelease(fn(connection())) : nil;
}
NSArray<NSNumber *> *WOSpacesForWindow(uint32_t wid) {
    CFArrayRef (*fn)(int,int,CFArrayRef) = dlsym(framework(), "SLSCopySpacesForWindows");
    return fn && wid ? CFBridgingRelease(fn(connection(), 7, (__bridge CFArrayRef)@[@(wid)])) : nil;
}
uint32_t WOWindowID(AXUIElementRef element) {
    AXError (*fn)(AXUIElementRef,uint32_t*) = dlsym(RTLD_DEFAULT, "_AXUIElementGetWindow");
    uint32_t wid = 0;
    if (fn) fn(element, &wid);
    return wid;
}
static BOOL perform(id operation) {
    SEL selector = NSSelectorFromString(@"performWithWMBridgeDelegate");
    if (!operation || ![operation respondsToSelector:selector]) return NO;
    ((void (*)(id,SEL))objc_msgSend)(operation, selector);
    return YES;
}
BOOL WOMoveWindowToSpace(uint32_t wid, uint64_t sid) {
    framework();
    @try {
        Class cls = NSClassFromString(@"SLSBridgedMoveWindowsToManagedSpaceOperation");
        SEL init = NSSelectorFromString(@"initWithWindows:spaceID:");
        if (!wid || !sid || ![cls instancesRespondToSelector:init]) return NO;
        id operation = ((id (*)(id,SEL,id,uint64_t))objc_msgSend)([cls alloc], init, @[@(wid)], sid);
        return perform(operation);
    } @catch (NSException *exception) { return NO; }
}
BOOL WOActivateSpace(NSString *displayID, uint64_t sid) {
    framework();
    @try {
        Class cls = NSClassFromString(@"SLSBridgedManagedDisplaySetCurrentSpaceOperation");
        SEL init = NSSelectorFromString(@"initWithDisplayIdentifier:spaceID:");
        if (!sid || ![cls instancesRespondToSelector:init]) return NO;
        id operation = ((id (*)(id,SEL,id,uint64_t))objc_msgSend)([cls alloc], init, displayID, sid);
        return perform(operation);
    } @catch (NSException *exception) { return NO; }
}
