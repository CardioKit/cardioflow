extension Array {
    func batch(size batchSize: Int, closure: ([Element]) -> Void) {
        guard batchSize > 0 else {
            print("Batch size must be greater than 0")
            return
        }

        var index = 0
        while index < self.count {
            let endIndex = index + batchSize
            let batch = Array(self[index..<Swift.min(endIndex, self.count)])
            closure(batch)
            index += batchSize
        }
    }
}
