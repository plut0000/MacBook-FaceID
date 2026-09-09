#ifndef CGSessionBridge_h
#define CGSessionBridge_h

#import <CoreGraphics/CoreGraphics.h>

// Undocumented but long-used CoreGraphics helper. Lets the app read whether
// the current Quartz session is locked after an unlock attempt.
CF_IMPLICIT_BRIDGING_ENABLED
CFDictionaryRef CGSessionCopyCurrentDictionary(void);
CF_IMPLICIT_BRIDGING_DISABLED

#endif
