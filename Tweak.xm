#import <Foundation/Foundation.h>
#import <Network/Network.h>

// Trigger iOS 18 Local Network permission prompt using NWBrowser
static void triggerLocalNetworkPrompt(void) {
    // Use Bonjour browser to trigger local network prompt
    nw_browse_descriptor_t descriptor = nw_browse_descriptor_create_bonjour_service("_http._tcp", "local.");
    nw_parameters_t params = nw_parameters_create();
    nw_browser_t browser = nw_browser_create(descriptor, params);
    
    nw_browser_set_queue(browser, dispatch_get_main_queue());
    nw_browser_set_browse_results_changed_handler(browser, ^(nw_browse_result_t result, nw_browse_result_t old_result, bool added) {
        // Just need to trigger the prompt, don't care about results
    });
    
    nw_browser_start(browser);
    
    // Cancel after 3 seconds
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3*NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        nw_browser_cancel(browser);
    });
}

%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3*NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        triggerLocalNetworkPrompt();
    });
}
