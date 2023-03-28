//  Created by Dariusz Niklewicz on 14/09/2021.

import Foundation
import SSDPKit

let ssdp = SSDPClient()

let publisher = ssdp.startScanning(for: 30)
var finished = false

let subscription = publisher.sink { completion in
    finished = true
    switch completion {
    case .finished:
        print("Completed")
    case .failure(let error):
        print("Completed with error:", error)
    }
} receiveValue: { url in
    print(url)
}

while !finished {
    sleep(1)
}
