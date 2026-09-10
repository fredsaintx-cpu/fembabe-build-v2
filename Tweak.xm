#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// Hook camera's float button class to change appearance
%hook iHsfaTkdhwkzopQfsnwBd

- (id)initWithFrame:(CGRect)frame {
    id result = %orig;
    if (result) {
        // Change to purple
        [self setBackgroundColor:[UIColor colorWithRed:0.5 green:0 blue:0.5 alpha:1]];
    }
    return result;
}

- (void)setTitle:(NSString *)title forState:(UIControlState)state {
    // Change B to F
    if ([title isEqualToString:@"B"]) {
        %orig(@"F", state);
    } else {
        %orig;
    }
}

- (void)setBackgroundColor:(UIColor *)color {
    // Force purple
    %orig([UIColor colorWithRed:0.5 green:0 blue:0.5 alpha:1]);
}

%end
