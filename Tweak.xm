#import <Foundation/Foundation.h>
#import <Network/Network.h>

// Trigger iOS 18 Local Network permission prompt
static void triggerLocalNetworkPrompt(void) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        nw_endpoint_t endpoint = nw_endpoint_create_host("224.0.0.1", "9999");
        nw_parameters_t params = nw_parameters_create_udp();
        nw_connection_t conn = nw_connection_create(endpoint, params);
        
        nw_connection_set_queue(conn, dispatch_get_main_queue());
        nw_connection_start(conn);
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2*NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            nw_connection_cancel(conn);
        });
    });
}

%ctor {
    // Trigger prompt 3 seconds after SpringBoard loads
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3*NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        triggerLocalNetworkPrompt();
    });
}
