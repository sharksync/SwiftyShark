//    MIT License
//
//    Copyright (c) 2016 SharkSync
//
//    Permission is hereby granted, free of charge, to any person obtaining a copy
//    of this software and associated documentation files (the "Software"), to deal
//    in the Software without restriction, including without limitation the rights
//    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//    copies of the Software, and to permit persons to whom the Software is
//    furnished to do so, subject to the following conditions:
//
//    The above copyright notice and this permission notice shall be included in all
//    copies or substantial portions of the Software.
//
//    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//    SOFTWARE.


import Foundation

class SyncNetwork  { 
    
    static let sharedInstance = SyncNetwork()
    init() {
        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
            self.runQueue()
        }
    }
    
    var endpoints: [String] = []
    
    // data to be sent with each request to the service
    var device_id: String?
    var app_id: String?
    var api_key: String?
    public var active: Bool = false
    
    // status change blocks
    private var connected: Bool = false
    private var connectionEstablishedClosure: (()->())? = nil
    private var connectionDisconnectedClosure: ((_ error: String?)->())? = nil

    private var lock: Mutex = Mutex()
    
    // set the block which gets executed when service is online & available
    // use this to setup the initial request framework
    
    func setConnectedClosure(_ closure: (()->())?) {
        connectionEstablishedClosure = closure
    }
    
    // set the block which gets executed when service is unavailable.
    // Such as out of credit, auth errors etc..., permanent errors, no connection
    func setDisconnectedClosure(_ closure: ((_ error: String?)->())?) {
        connectionDisconnectedClosure = closure
    }
    
    func runQueue() {
        
        let r = SyncRequest()
        
        while(true) {
            
            if active {
            
                makeRequest(r)
                
            }
            
            Thread.sleep(forTimeInterval: 1)
            
        }
        
    }
    
    func makeRequest(_ r: SyncRequest) {
        
        let s = SyncComms()
        let response = s.request(payload: r.requestObject())
        if response != nil {
            r.requestResponded(response!, changes: r.changes)
        } else {
            
        }
        
    }
    
    func synchroniseNow() {
        makeRequest(SyncRequest())
    }
}
