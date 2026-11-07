#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>
NS_ASSUME_NONNULL_BEGIN
NSArray<NSDictionary *> * _Nullable WODisplaySpaces(void);
NSArray<NSNumber *> * _Nullable WOSpacesForWindow(uint32_t windowID);
uint32_t WOWindowID(AXUIElementRef element);
BOOL WOMoveWindowToSpace(uint32_t windowID, uint64_t spaceID);
BOOL WOActivateSpace(NSString *displayID, uint64_t spaceID);
NS_ASSUME_NONNULL_END
