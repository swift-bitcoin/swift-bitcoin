import Foundation

struct BigUInt: UnsignedInteger {

    typealias Word = UInt

    enum Kind {
        case inline(Word, Word)
        case slice(from: Int, to: Int)
        case array
    }

    fileprivate(set) var kind: Kind // Internal for testing only
    fileprivate(set) var storage: [Word] // Internal for testing only; stored separately to prevent COW copies

    init() {
        self.kind = .inline(0, 0)
        self.storage = []
    }

    init(word: Word) {
        self.kind = .inline(word, 0)
        self.storage = []
    }

    init(low: Word, high: Word) {
        self.kind = .inline(low, high)
        self.storage = []
    }

    init(words: [Word]) {
        self.kind = .array
        self.storage = words
        normalize()
    }

    init(words: [Word], from startIndex: Int, to endIndex: Int) {
        self.kind = .slice(from: startIndex, to: endIndex)
        self.storage = words
        normalize()
    }
}

extension BigUInt: Hashable {

    func hash(into hasher: inout Hasher) {
        for word in self.words {
            hasher.combine(word)
        }
    }
}

extension BigUInt {
    static var isSigned: Bool { false }

    var isZero: Bool {
        switch kind {
        case .inline(0, 0): true
        case .array: storage.isEmpty
        default: false
        }
    }

    func signum() -> BigUInt {
        return isZero ? 0 : 1
    }
}

extension BigUInt {
    mutating func ensureArray() {
        switch kind {
        case let .inline(w0, w1):
            kind = .array
            storage = w1 != 0 ? [w0, w1]
                : w0 != 0 ? [w0]
                : []
        case let .slice(from: start, to: end):
            kind = .array
            storage = Array(storage[start ..< end])
        case .array:
            break
        }
    }

    var capacity: Int {
        guard case .array = kind else { return 0 }
        return storage.capacity
    }

    mutating func reserveCapacity(_ minimumCapacity: Int) {
        switch kind {
        case let .inline(w0, w1):
            kind = .array
            storage.reserveCapacity(minimumCapacity)
            if w1 != 0 {
                storage.append(w0)
                storage.append(w1)
            }
            else if w0 != 0 {
                storage.append(w0)
            }
        case let .slice(from: start, to: end):
            kind = .array
            var words: [Word] = []
            words.reserveCapacity(Swift.max(end - start, minimumCapacity))
            words.append(contentsOf: storage[start ..< end])
            storage = words
        case .array:
            storage.reserveCapacity(minimumCapacity)
        }
    }

    mutating func normalize() {
        switch kind {
        case .slice(from: let start, to: var end):
            assert(start >= 0 && end <= storage.count && start <= end)
            while start < end, storage[end - 1] == 0 {
                end -= 1
            }
            switch end - start {
            case 0:
                kind = .inline(0, 0)
                storage = []
            case 1:
                kind = .inline(storage[start], 0)
                storage = []
            case 2:
                kind = .inline(storage[start], storage[start + 1])
                storage = []
            case storage.count:
                assert(start == 0)
                kind = .array
            default:
                kind = .slice(from: start, to: end)
            }
        case .array where storage.last == 0:
            while storage.last == 0 {
                storage.removeLast()
            }
        default:
            break
        }
    }

    mutating func clear() {
        self.load(BigUInt(0))
    }

    mutating func load(_ value: BigUInt) {
        switch kind {
        case .inline, .slice:
            self = value
        case .array:
            self.storage.removeAll(keepingCapacity: true)
            self.storage.append(contentsOf: value.words)
        }
    }
}

extension BigUInt { // Collection

    var count: Int {
        switch kind {
        case let .inline(w0, w1):
            return w1 != 0 ? 2
                : w0 != 0 ? 1
                : 0
        case let .slice(from: start, to: end):
            return end - start
        case .array:
            return storage.count
        }
    }

    subscript(_ index: Int) -> Word {
        get {
            precondition(index >= 0)
            switch (kind, index) {
            case (.inline(let w0, _), 0): return w0
            case (.inline(_, let w1), 1): return w1
            case (.slice(from: let start, to: let end), _) where index < end - start:
                return storage[start + index]
            case (.array, _) where index < storage.count:
                return storage[index]
            default:
                return 0
            }
        }
        set(word) {
            precondition(index >= 0)
            switch (kind, index) {
            case let (.inline(_, w1), 0):
                kind = .inline(word, w1)
            case let (.inline(w0, _), 1):
                kind = .inline(w0, word)
            case let (.slice(from: start, to: end), _) where index < end - start:
                replace(at: index, with: word)
            case (.array, _) where index < storage.count:
                replace(at: index, with: word)
            default:
                extend(at: index, with: word)
            }
        }
    }

    private mutating func replace(at index: Int, with word: Word) {
        ensureArray()
        precondition(index < storage.count)
        storage[index] = word
        if word == 0, index == storage.count - 1 {
            normalize()
        }
    }

    private mutating func extend(at index: Int, with word: Word) {
        guard word != 0 else { return }
        reserveCapacity(index + 1)
        precondition(index >= storage.count)
        storage.append(contentsOf: repeatElement(0, count: index - storage.count))
        storage.append(word)
    }

    func extract(_ bounds: Range<Int>) -> BigUInt {
        switch kind {
        case let .inline(w0, w1):
            let bounds = bounds.clamped(to: 0 ..< 2)
            if bounds == 0 ..< 2 {
                return BigUInt(low: w0, high: w1)
            }
            else if bounds == 0 ..< 1 {
                return BigUInt(word: w0)
            }
            else if bounds == 1 ..< 2 {
                return BigUInt(word: w1)
            }
            else {
                return BigUInt()
            }
        case let .slice(from: start, to: end):
            let s = Swift.min(end, start + Swift.max(bounds.lowerBound, 0))
            let e = Swift.max(s, (bounds.upperBound > end - start ? end : start + bounds.upperBound))
            return BigUInt(words: storage, from: s, to: e)
        case .array:
            let b = bounds.clamped(to: storage.startIndex ..< storage.endIndex)
            return BigUInt(words: storage, from: b.lowerBound, to: b.upperBound)
        }
    }

    func extract<Bounds: RangeExpression>(_ bounds: Bounds) -> BigUInt where Bounds.Bound == Int {
        return self.extract(bounds.relative(to: 0 ..< Int.max))
    }
}

extension BigUInt { // Shift
    mutating func shiftRight(byWords amount: Int) {
        assert(amount >= 0)
        guard amount > 0 else { return }
        switch kind {
        case let .inline(_, w1) where amount == 1:
            kind = .inline(w1, 0)
        case .inline(_, _):
            kind = .inline(0, 0)
        case let .slice(from: start, to: end):
            let s = start + amount
            if s >= end {
                kind = .inline(0, 0)
            }
            else {
                kind = .slice(from: s, to: end)
                normalize()
            }
        case .array:
            if amount >= storage.count {
                storage.removeAll(keepingCapacity: true)
            }
            else {
                storage.removeFirst(amount)
            }
        }
    }

    mutating func shiftLeft(byWords amount: Int) {
        assert(amount >= 0)
        guard amount > 0 else { return }
        guard !isZero else { return }
        switch kind {
        case let .inline(w0, 0) where amount == 1:
            kind = .inline(0, w0)
        case let .inline(w0, w1):
            let c = (w1 == 0 ? 1 : 2)
            storage.reserveCapacity(amount + c)
            storage.append(contentsOf: repeatElement(0, count: amount))
            storage.append(w0)
            if w1 != 0 {
                storage.append(w1)
            }
            kind = .array
        case let .slice(from: start, to: end):
            var words: [Word] = []
            words.reserveCapacity(amount + count)
            words.append(contentsOf: repeatElement(0, count: amount))
            words.append(contentsOf: storage[start ..< end])
            storage = words
            kind = .array
        case .array:
            storage.insert(contentsOf: repeatElement(0, count: amount), at: 0)
        }
    }
}

extension BigUInt { // Low and High

    var split: (high: BigUInt, low: BigUInt) {
        precondition(count > 1)
        let mid = middleIndex
        return (self.extract(mid...), self.extract(..<mid))
    }

    var middleIndex: Int {
        (count + 1) / 2
    }

    var low: BigUInt {
        self.extract(0 ..< middleIndex)
    }

    var high: BigUInt {
        self.extract(middleIndex ..< count)
    }
}

extension BigUInt { // Floating Point
    init?<T: BinaryFloatingPoint>(exactly source: T) {
        guard source.isFinite else { return nil }
        guard !source.isZero else { self = 0; return }
        guard source.sign == .plus else { return nil }
        let value = source.rounded(.towardZero)
        guard value == source else { return nil }
        assert(value.floatingPointClass == .positiveNormal)
        assert(value.exponent >= 0)
        let significand = value.significandBitPattern
        self = (BigUInt(1) << value.exponent) + BigUInt(significand) >> (T.significandBitCount - Int(value.exponent))
    }

    init<T: BinaryFloatingPoint>(_ source: T) {
        self.init(exactly: source.rounded(.towardZero))!
    }
}

extension BigUInt { // Addition

    mutating func addWord(_ word: Word, shiftedBy shift: Int = 0) {
        precondition(shift >= 0)
        var carry = word
        var i = shift
        while carry > 0 {
            let (d, c) = self[i].addingReportingOverflow(carry)
            self[i] = d
            carry = (c ? 1 : 0)
            i += 1
        }
    }

    func addingWord(_ word: Word, shiftedBy shift: Int = 0) -> BigUInt {
        var r = self
        r.addWord(word, shiftedBy: shift)
        return r
    }

    mutating func add(_ b: BigUInt, shiftedBy shift: Int = 0) {
        precondition(shift >= 0)
        var carry = false
        var bi = 0
        let bc = b.count
        while bi < bc || carry {
            let ai = shift + bi
            let (d, c) = self[ai].addingReportingOverflow(b[bi])
            if carry {
                let (d2, c2) = d.addingReportingOverflow(1)
                self[ai] = d2
                carry = c || c2
            }
            else {
                self[ai] = d
                carry = c
            }
            bi += 1
        }
    }

    func adding(_ b: BigUInt, shiftedBy shift: Int = 0) -> BigUInt {
        var r = self
        r.add(b, shiftedBy: shift)
        return r
    }

    mutating func increment(shiftedBy shift: Int = 0) {
        self.addWord(1, shiftedBy: shift)
    }

    static func +(a: BigUInt, b: BigUInt) -> BigUInt {
        a.adding(b)
    }

    static func +=(a: inout BigUInt, b: BigUInt) {
        a.add(b, shiftedBy: 0)
    }
}

extension BigUInt { // Multiplication

    mutating func multiply(byWord y: Word) {
        guard y != 0 else { self = 0; return }
        guard y != 1 else { return }
        var carry: Word = 0
        let c = self.count
        for i in 0 ..< c {
            let (h, l) = self[i].multipliedFullWidth(by: y)
            let (low, o) = l.addingReportingOverflow(carry)
            self[i] = low
            carry = (o ? h + 1 : h)
        }
        self[c] = carry
    }

    func multiplied(byWord y: Word) -> BigUInt {
        var r = self
        r.multiply(byWord: y)
        return r
    }

    mutating func multiplyAndAdd(_ x: BigUInt, _ y: Word, shiftedBy shift: Int = 0) {
        precondition(shift >= 0)
        guard y != 0 && x.count > 0 else { return }
        guard y != 1 else { self.add(x, shiftedBy: shift); return }
        var mulCarry: Word = 0
        var addCarry = false
        let xc = x.count
        var xi = 0
        while xi < xc || addCarry || mulCarry > 0 {
            let (h, l) = x[xi].multipliedFullWidth(by: y)
            let (low, o) = l.addingReportingOverflow(mulCarry)
            mulCarry = (o ? h + 1 : h)

            let ai = shift + xi
            let (sum1, so1) = self[ai].addingReportingOverflow(low)
            if addCarry {
                let (sum2, so2) = sum1.addingReportingOverflow(1)
                self[ai] = sum2
                addCarry = so1 || so2
            }
            else {
                self[ai] = sum1
                addCarry = so1
            }
            xi += 1
        }
    }

    func multiplied(by y: BigUInt) -> BigUInt {
        // This method is mostly defined for symmetry with the rest of the arithmetic operations.
        return self * y
    }

    static let directMultiplicationLimit: Int = 1024

    static func *(x: BigUInt, y: BigUInt) -> BigUInt {
        let xc = x.count
        let yc = y.count
        if xc == 0 { return BigUInt() }
        if yc == 0 { return BigUInt() }
        if yc == 1 { return x.multiplied(byWord: y[0]) }
        if xc == 1 { return y.multiplied(byWord: x[0]) }

        if Swift.min(xc, yc) <= BigUInt.directMultiplicationLimit {
            // Long multiplication.
            let left = (xc < yc ? y : x)
            let right = (xc < yc ? x : y)
            var result = BigUInt()
            for i in (0 ..< right.count).reversed() {
                result.multiplyAndAdd(left, right[i], shiftedBy: i)
            }
            return result
        }

        if yc < xc {
            let (xh, xl) = x.split
            var r = xl * y
            r.add(xh * y, shiftedBy: x.middleIndex)
            return r
        }
        else if xc < yc {
            let (yh, yl) = y.split
            var r = yl * x
            r.add(yh * x, shiftedBy: y.middleIndex)
            return r
        }

        let shift = x.middleIndex

        // Karatsuba multiplication:
        // x * y = <a,b> * <c,d> = <ac, ac + bd - (a-b)(c-d), bd> (ignoring carry)
        let (a, b) = x.split
        let (c, d) = y.split

        let high = a * c
        let low = b * d
        let xp = a >= b
        let yp = c >= d
        let xm = (xp ? a - b : b - a)
        let ym = (yp ? c - d : d - c)
        let m = xm * ym

        var r = low
        r.add(high, shiftedBy: 2 * shift)
        r.add(low, shiftedBy: shift)
        r.add(high, shiftedBy: shift)
        if xp == yp {
            r.subtract(m, shiftedBy: shift)
        }
        else {
            r.add(m, shiftedBy: shift)
        }
        return r
    }

    static func *=(a: inout BigUInt, b: BigUInt) {
        a = a * b
    }
}

extension BigUInt { // Data Conversion

    init(_ buffer: UnsafeRawBufferPointer) {
        // This assumes Word is binary.
        precondition(Word.bitWidth % 8 == 0)

        self.init()

        let length = buffer.count
        guard length > 0 else { return }
        let bytesPerDigit = Word.bitWidth / 8
        var index = length / bytesPerDigit
        var c = bytesPerDigit - length % bytesPerDigit
        if c == bytesPerDigit {
            c = 0
            index -= 1
        }

        var word: Word = 0
        for byte in buffer {
            word <<= 8
            word += Word(byte)
            c += 1
            if c == bytesPerDigit {
                self[index] = word
                index -= 1
                c = 0
                word = 0
            }
        }
        assert(c == 0 && word == 0 && index == -1)
    }

    init(_ data: Data) {
        // This assumes Word is binary.
        precondition(Word.bitWidth % 8 == 0)

        self.init()

        let length = data.count
        guard length > 0 else { return }
        let bytesPerDigit = Word.bitWidth / 8
        var index = length / bytesPerDigit
        var c = bytesPerDigit - length % bytesPerDigit
        if c == bytesPerDigit {
            c = 0
            index -= 1
        }
        let word: Word = data.withUnsafeBytes { buffPtr in
            var word: Word = 0
            let p = buffPtr.bindMemory(to: UInt8.self)
            for byte in p {
                word <<= 8
                word += Word(byte)
                c += 1
                if c == bytesPerDigit {
                    self[index] = word
                    index -= 1
                    c = 0
                    word = 0
                }
            }
            return word
        }
        assert(c == 0 && word == 0 && index == -1)
    }

    var data: Data {
        // This assumes Digit is binary.
        precondition(Word.bitWidth % 8 == 0)

        let byteCount = (self.bitWidth + 7) / 8

        guard byteCount > 0 else { return Data() }

        var data = Data(count: byteCount)
        data.withUnsafeMutableBytes { buffPtr in
            let p = buffPtr.bindMemory(to: UInt8.self)
            var i = byteCount - 1
            for var word in self.words {
                for _ in 0 ..< Word.bitWidth / 8 {
                    p[i] = UInt8(word & 0xFF)
                    word >>= 8
                    if i == 0 {
                        assert(word == 0)
                        break
                    }
                    i -= 1
                }
            }
        }
        return data
    }
}

extension BigUInt {
    init?<T: BinaryInteger>(exactly source: T) {
        guard source >= (0 as T) else { return nil }
        if source.bitWidth <= 2 * Word.bitWidth {
            var it = source.words.makeIterator()
            self.init(low: it.next() ?? 0, high: it.next() ?? 0)
            precondition(it.next() == nil, "Length of BinaryInteger.words is greater than its bitWidth")
        }
        else {
            self.init(words: source.words)
        }
    }

    init<T: BinaryInteger>(_ source: T) {
        precondition(source >= (0 as T), "BigUInt cannot represent negative values")
        self.init(exactly: source)!
    }

    init<T: BinaryInteger>(truncatingIfNeeded source: T) {
        self.init(words: source.words)
    }

    init<T: BinaryInteger>(clamping source: T) {
        if source <= (0 as T) {
            self.init()
        }
        else {
            self.init(words: source.words)
        }
    }
}

extension BigUInt { // Words

    var bitWidth: Int {
        guard count > 0 else { return 0 }
        return count * Word.bitWidth - self[count - 1].leadingZeroBitCount
    }

    var leadingZeroBitCount: Int {
        guard count > 0 else { return 0 }
        return self[count - 1].leadingZeroBitCount
    }

    var trailingZeroBitCount: Int {
        guard count > 0 else { return 0 }
        let i = self.words.firstIndex { $0 != 0 }!
        return i * Word.bitWidth + self[i].trailingZeroBitCount
    }

    struct Words: RandomAccessCollection {
        private let value: BigUInt

        fileprivate init(_ value: BigUInt) { self.value = value }

        var startIndex: Int { return 0 }
        var endIndex: Int { return value.count }

        subscript(_ index: Int) -> Word {
            return value[index]
        }
    }

    var words: Words { return Words(self) }

    init<Words: Sequence>(words: Words) where Words.Element == Word {
        let uc = words.underestimatedCount
        if uc > 2 {
            self.init(words: Array(words))
        }
        else {
            var it = words.makeIterator()
            guard let w0 = it.next() else {
                self.init()
                return
            }
            guard let w1 = it.next() else {
                self.init(word: w0)
                return
            }
            if let w2 = it.next() {
                var words: [UInt] = []
                words.reserveCapacity(Swift.max(3, uc))
                words.append(w0)
                words.append(w1)
                words.append(w2)
                while let word = it.next() {
                    words.append(word)
                }
                self.init(words: words)
            }
            else {
                self.init(low: w0, high: w1)
            }
        }
    }
}

extension BigUInt { // Subtraction

    mutating func subtractWordReportingOverflow(_ word: Word, shiftedBy shift: Int = 0) -> Bool {
        precondition(shift >= 0)
        var carry: Word = word
        var i = shift
        let count = self.count
        while carry > 0 && i < count {
            let (d, c) = self[i].subtractingReportingOverflow(carry)
            self[i] = d
            carry = (c ? 1 : 0)
            i += 1
        }
        return carry > 0
    }

    func subtractingWordReportingOverflow(_ word: Word, shiftedBy shift: Int = 0) -> (partialValue: BigUInt, overflow: Bool) {
        var result = self
        let overflow = result.subtractWordReportingOverflow(word, shiftedBy: shift)
        return (result, overflow)
    }

    mutating func subtractWord(_ word: Word, shiftedBy shift: Int = 0) {
        let overflow = subtractWordReportingOverflow(word, shiftedBy: shift)
        precondition(!overflow)
    }

    func subtractingWord(_ word: Word, shiftedBy shift: Int = 0) -> BigUInt {
        var result = self
        result.subtractWord(word, shiftedBy: shift)
        return result
    }

    mutating func subtractReportingOverflow(_ b: BigUInt, shiftedBy shift: Int = 0) -> Bool {
        precondition(shift >= 0)
        var carry = false
        var bi = 0
        let bc = b.count
        let count = self.count
        while bi < bc || (shift + bi < count && carry) {
            let ai = shift + bi
            let (d, c) = self[ai].subtractingReportingOverflow(b[bi])
            if carry {
                let (d2, c2) = d.subtractingReportingOverflow(1)
                self[ai] = d2
                carry = c || c2
            }
            else {
                self[ai] = d
                carry = c
            }
            bi += 1
        }
        return carry
    }

    func subtractingReportingOverflow(_ other: BigUInt, shiftedBy shift: Int) -> (partialValue: BigUInt, overflow: Bool) {
        var result = self
        let overflow = result.subtractReportingOverflow(other, shiftedBy: shift)
        return (result, overflow)
    }
    
    func subtractingReportingOverflow(_ other: BigUInt) -> (partialValue: BigUInt, overflow: Bool) {
        return self.subtractingReportingOverflow(other, shiftedBy: 0)
    }
    
    mutating func subtract(_ other: BigUInt, shiftedBy shift: Int = 0) {
        let overflow = subtractReportingOverflow(other, shiftedBy: shift)
        precondition(!overflow)
    }

    func subtracting(_ other: BigUInt, shiftedBy shift: Int = 0) -> BigUInt {
        var result = self
        result.subtract(other, shiftedBy: shift)
        return result
    }

    mutating func decrement(shiftedBy shift: Int = 0) {
        self.subtract(1, shiftedBy: shift)
    }

    static func -(a: BigUInt, b: BigUInt) -> BigUInt {
        a.subtracting(b)
    }

    static func -=(a: inout BigUInt, b: BigUInt) {
        a.subtract(b)
    }
}

extension BigUInt: Comparable { // Comparison

    static func compare(_ a: BigUInt, _ b: BigUInt) -> ComparisonResult {
        if a.count != b.count { return a.count > b.count ? .orderedDescending : .orderedAscending }
        for i in (0 ..< a.count).reversed() {
            let ad = a[i]
            let bd = b[i]
            if ad != bd { return ad > bd ? .orderedDescending : .orderedAscending }
        }
        return .orderedSame
    }

    static func ==(a: BigUInt, b: BigUInt) -> Bool {
        return BigUInt.compare(a, b) == .orderedSame
    }

    static func <(a: BigUInt, b: BigUInt) -> Bool {
        return BigUInt.compare(a, b) == .orderedAscending
    }
}

extension BigUInt { // Division

    mutating func divide(byWord y: Word) -> Word {
        precondition(y > 0)
        if y == 1 { return 0 }
        
        var remainder: Word = 0
        for i in (0 ..< count).reversed() {
            let u = self[i]
            (self[i], remainder) = y.fastDividingFullWidth((remainder, u))
        }
        return remainder
    }

    func quotientAndRemainder(dividingByWord y: Word) -> (quotient: BigUInt, remainder: Word) {
        var div = self
        let mod = div.divide(byWord: y)
        return (div, mod)
    }

    static func divide(_ x: inout BigUInt, by y: inout BigUInt) {
        // This is a Swift adaptation of "divmnu" from Hacker's Delight, which is in
        // turn a C adaptation of Knuth's Algorithm D (TAOCP vol 2, 4.3.1).

        precondition(!y.isZero)

        // First, let's take care of the easy cases.
        if x < y {
            (x, y) = (0, x)
            return
        }
        if y.count == 1 {
            // The single-word case reduces to a simpler loop.
            y = BigUInt(x.divide(byWord: y[0]))
            return
        }

        // In the hard cases, we will perform the long division algorithm we learned in school.
        // It works by successively calculating the single-word quotient of the top y.count + 1
        // words of x divided by y, replacing the top of x with the remainder, and repeating
        // the process one word lower.
        //
        // The tricky part is that the algorithm needs to be able to do n+1/n word divisions,
        // but we only have a primitive for dividing two words by a single
        // word. (Remember that this step is also tricky when we do it on paper!)
        //
        // The solution is that the long division can be approximated by a single full division
        // using just the most significant words. We can then use multiplications and
        // subtractions to refine the approximation until we get the correct quotient word.
        //
        // We could do this by doing a simple 2/1 full division, but Knuth goes one step further,
        // and implements a 3/2 division. This results in an exact approximation in the
        // vast majority of cases, eliminating an extra subtraction over big integers.
        //
        // The function `approximateQuotient` above implements Knuth's 3/2 division algorithm.
        // It requires that the divisor's most significant word is larger than
        // Word.max / 2. This ensures that the approximation has tiny error bounds,
        // which is what makes this entire approach viable.
        // To satisfy this requirement, we will normalize the division by multiplying
        // both the divisor and the dividend by the same (small) factor.
        let z = y.leadingZeroBitCount
        y <<= z
        x <<= z // We'll calculate the remainder in the normalized dividend.
        var quotient = BigUInt()
        assert(y.leadingZeroBitCount == 0)

        // We're ready to start the long division!
        let dc = y.count
        let d1 = y[dc - 1]
        let d0 = y[dc - 2]
        var product: BigUInt = 0
        for j in (dc ... x.count).reversed() {
            // Approximate dividing the top dc+1 words of `remainder` using the topmost 3/2 words.
            let r2 = x[j]
            let r1 = x[j - 1]
            let r0 = x[j - 2]
            let q = Word.approximateQuotient(dividing: (r2, r1, r0), by: (d1, d0))

            // Multiply the entire divisor with `q` and subtract the result from remainder.
            // Normalization ensures the 3/2 quotient will either be exact for the full division, or
            // it may overshoot by at most 1, in which case the product will be greater
            // than the remainder.
            product.load(y)
            product.multiply(byWord: q)
            if product <= x.extract(j - dc ..< j + 1) {
                x.subtract(product, shiftedBy: j - dc)
                quotient[j - dc] = q
            }
            else {
                // This case is extremely rare -- it has a probability of 1/2^(Word.bitWidth - 1).
                x.add(y, shiftedBy: j - dc)
                x.subtract(product, shiftedBy: j - dc)
                quotient[j - dc] = q - 1
            }
        }
        // The remainder's normalization needs to be undone, but otherwise we're done.
        x >>= z
        y = x
        x = quotient
    }

    mutating func formRemainder(dividingBy y: BigUInt, normalizedBy shift: Int) {
        precondition(!y.isZero)
        assert(y.leadingZeroBitCount == 0)
        if y.count == 1 {
            let remainder = self.divide(byWord: y[0] >> shift)
            self.load(BigUInt(remainder))
            return
        }
        self <<= shift
        if self >= y {
            let dc = y.count
            let d1 = y[dc - 1]
            let d0 = y[dc - 2]
            var product: BigUInt = 0
            for j in (dc ... self.count).reversed() {
                let r2 = self[j]
                let r1 = self[j - 1]
                let r0 = self[j - 2]
                let q = Word.approximateQuotient(dividing: (r2, r1, r0), by: (d1, d0))
                product.load(y)
                product.multiply(byWord: q)
                if product <= self.extract(j - dc ..< j + 1) {
                    self.subtract(product, shiftedBy: j - dc)
                }
                else {
                    self.add(y, shiftedBy: j - dc)
                    self.subtract(product, shiftedBy: j - dc)
                }
            }
        }
        self >>= shift
    }

    func quotientAndRemainder(dividingBy y: BigUInt) -> (quotient: BigUInt, remainder: BigUInt) {
        var x = self
        var y = y
        BigUInt.divide(&x, by: &y)
        return (x, y)
    }

    static func /(x: BigUInt, y: BigUInt) -> BigUInt {
        return x.quotientAndRemainder(dividingBy: y).quotient
    }

    static func %(x: BigUInt, y: BigUInt) -> BigUInt {
        var x = x
        let shift = y.leadingZeroBitCount
        x.formRemainder(dividingBy: y << shift, normalizedBy: shift)
        return x
    }

    static func /=(x: inout BigUInt, y: BigUInt) {
        var y = y
        BigUInt.divide(&x, by: &y)
    }

    static func %=(x: inout BigUInt, y: BigUInt) {
        let shift = y.leadingZeroBitCount
        x.formRemainder(dividingBy: y << shift, normalizedBy: shift)
    }
}

fileprivate extension FixedWidthInteger {

    private var halfShift: Self {
        return Self(Self.bitWidth / 2)

    }
    private var high: Self {
        return self &>> halfShift
    }

    private var low: Self {
        let mask: Self = 1 &<< halfShift - 1
        return self & mask
    }

    private var upshifted: Self {
        return self &<< halfShift
    }

    private var split: (high: Self, low: Self) {
        return (self.high, self.low)
    }

    private init(_ value: (high: Self, low: Self)) {
        self = value.high.upshifted + value.low
    }

    func fastDividingFullWidth(_ dividend: (high: Self, low: Self.Magnitude)) -> (quotient: Self, remainder: Self) {
        // Division is complicated; doing it with single-digit operations is maddeningly complicated.
        // This is a Swift adaptation for "divlu2" in Hacker's Delight,
        // which is in turn a C adaptation of Knuth's Algorithm D (TAOCP vol 2, 4.3.1).
        precondition(dividend.high < self)

        // This replaces the implementation in stdlib, which is much slower.
        // FIXME: Speed up stdlib. It should use full-width idiv on Intel processors, and
        // fall back to a reasonably fast algorithm elsewhere.

        // The trick here is that we're actually implementing a 4/2 long division using half-words,
        // with the long division loop unrolled into two 3/2 half-word divisions.
        // Luckily, 3/2 half-word division can be approximated by a single full-word division operation
        // that, when the divisor is normalized, differs from the correct result by at most 2.

        func quotient(dividing u: (high: Self, low: Self), by vn: Self) -> Self {
            let (vn1, vn0) = vn.split
            // Get approximate quotient.
            let (q, r) = u.high.quotientAndRemainder(dividingBy: vn1)
            let p = q * vn0
            // q is often already correct, but sometimes the approximation overshoots by at most 2.
            // The code that follows checks for this while being careful to only perform single-digit operations.
            if q.high == 0 && p <= r.upshifted + u.low { return q }
            let r2 = r + vn1
            if r2.high != 0 { return q - 1 }
            if (q - 1).high == 0 && p - vn0 <= r2.upshifted + u.low { return q - 1 }
            //assert((r + 2 * vn1).high != 0 || p - 2 * vn0 <= (r + 2 * vn1).upshifted + u.low)
            return q - 2
        }

        func quotientAndRemainder(dividing u: (high: Self, low: Self), by v: Self) -> (quotient: Self, remainder: Self) {
            let q = quotient(dividing: u, by: v)
            // Note that `uh.low` masks off a couple of bits, and `q * v` and the
            // subtraction are likely to overflow. Despite this, the end result (remainder) will
            // still be correct and it will fit inside a single (full) Digit.
            let r = Self(u) &- q &* v
            assert(r < v)
            return (q, r)
        }

        // Normalize the dividend and the divisor (self) such that the divisor has no leading zeroes.
        let z = Self(self.leadingZeroBitCount)
        let w = Self(Self.bitWidth) - z
        let vn = self << z

        let un32 = (z == 0 ? dividend.high : (dividend.high &<< z) | ((dividend.low as! Self) &>> w)) // No bits are lost
        let un10 = dividend.low &<< z
        let (un1, un0) = un10.split

        // Divide `(un32,un10)` by `vn`, splitting the full 4/2 division into two 3/2 ones.
        let (q1, un21) = quotientAndRemainder(dividing: (un32, (un1 as! Self)), by: vn)
        let (q0, rn) = quotientAndRemainder(dividing: (un21, (un0 as! Self)), by: vn)

        // Undo normalization of the remainder and combine the two halves of the quotient.
        let mod = rn >> z
        let div = Self((q1, q0))
        return (div, mod)
    }

    static func approximateQuotient(dividing x: (Self, Self, Self), by y: (Self, Self)) -> Self {
        // Start with q = (x.0, x.1) / y.0, (or Word.max on overflow)
        var q: Self
        var r: Self
        if x.0 == y.0 {
            q = Self.max
            let (s, o) = x.0.addingReportingOverflow(x.1)
            if o { return q }
            r = s
        }
        else {
            (q, r) = y.0.fastDividingFullWidth((x.0, (x.1 as! Magnitude)))
        }
        // Now refine q by considering x.2 and y.1.
        // Note that since y is normalized, q * y - x is between 0 and 2.
        let (ph, pl) = q.multipliedFullWidth(by: y.1)
        if ph < r || (ph == r && pl <= x.2) { return q }

        let (r1, ro) = r.addingReportingOverflow(y.0)
        if ro { return q - 1 }

        let (pl1, so) = pl.subtractingReportingOverflow((y.1 as! Magnitude))
        let ph1 = (so ? ph - 1 : ph)

        if ph1 < r1 || (ph1 == r1 && pl1 <= x.2) { return q - 1 }
        return q - 2
    }
}

extension BigUInt: ExpressibleByIntegerLiteral {

    init(integerLiteral value: UInt64) {
        self.init(value)
    }
}

extension BigUInt { // Shift Operators

    func shiftedLeft(by amount: Word) -> BigUInt {
        guard amount > 0 else { return self }
        
        let ext = Int(amount / Word(Word.bitWidth)) // External shift amount (new words)
        let up = Word(amount % Word(Word.bitWidth)) // Internal shift amount (subword shift)
        let down = Word(Word.bitWidth) - up
        
        var result = BigUInt()
        if up > 0 {
            var i = 0
            var lowbits: Word = 0
            while i < self.count || lowbits > 0 {
                let word = self[i]
                result[i + ext] = word << up | lowbits
                lowbits = word >> down
                i += 1
            }
        }
        else {
            for i in 0 ..< self.count {
                result[i + ext] = self[i]
            }
        }
        return result
    }
    
    mutating func shiftLeft(by amount: Word) {
        guard amount > 0 else { return }
        
        let ext = Int(amount / Word(Word.bitWidth)) // External shift amount (new words)
        let up = Word(amount % Word(Word.bitWidth)) // Internal shift amount (subword shift)
        let down = Word(Word.bitWidth) - up
        
        if up > 0 {
            var i = 0
            var lowbits: Word = 0
            while i < self.count || lowbits > 0 {
                let word = self[i]
                self[i] = word << up | lowbits
                lowbits = word >> down
                i += 1
            }
        }
        if ext > 0 && self.count > 0 {
            self.shiftLeft(byWords: ext)
        }
    }
    
    func shiftedRight(by amount: Word) -> BigUInt {
        guard amount > 0 else { return self }
        guard amount < self.bitWidth else { return 0 }
        
        let ext = Int(amount / Word(Word.bitWidth)) // External shift amount (new words)
        let down = Word(amount % Word(Word.bitWidth)) // Internal shift amount (subword shift)
        let up = Word(Word.bitWidth) - down
        
        var result = BigUInt()
        if down > 0 {
            var highbits: Word = 0
            for i in (ext ..< self.count).reversed() {
                let word = self[i]
                result[i - ext] = highbits | word >> down
                highbits = word << up
            }
        }
        else {
            for i in (ext ..< self.count).reversed() {
                result[i - ext] = self[i]
            }
        }
        return result
    }

    mutating func shiftRight(by amount: Word) {
        guard amount > 0 else { return }
        guard amount < self.bitWidth else { self.clear(); return }
        
        let ext = Int(amount / Word(Word.bitWidth)) // External shift amount (new words)
        let down = Word(amount % Word(Word.bitWidth)) // Internal shift amount (subword shift)
        let up = Word(Word.bitWidth) - down
        
        if ext > 0 {
            self.shiftRight(byWords: ext)
        }
        if down > 0 {
            var i = self.count - 1
            var highbits: Word = 0
            while i >= 0 {
                let word = self[i]
                self[i] = highbits | word >> down
                highbits = word << up
                i -= 1
            }
        }
    }
    
    static func >>=<Other: BinaryInteger>(lhs: inout BigUInt, rhs: Other) {
        if rhs < (0 as Other) {
            lhs <<= (0 - rhs)
        }
        else if rhs >= lhs.bitWidth {
            lhs.clear()
        }
        else {
            lhs.shiftRight(by: UInt(rhs))
        }
    }
    
    static func <<=<Other: BinaryInteger>(lhs: inout BigUInt, rhs: Other) {
        if rhs < (0 as Other) {
            lhs >>= (0 - rhs)
            return
        }
        lhs.shiftLeft(by: Word(exactly: rhs)!)
    }

    static func >><Other: BinaryInteger>(lhs: BigUInt, rhs: Other) -> BigUInt {
        if rhs < (0 as Other) {
            return lhs << (0 - rhs)
        }
        if rhs > Word.max {
            return 0
        }
        return lhs.shiftedRight(by: UInt(rhs))
    }

    static func <<<Other: BinaryInteger>(lhs: BigUInt, rhs: Other) -> BigUInt {
        if rhs < (0 as Other) {
            return lhs >> (0 - rhs)
        }
        return lhs.shiftedLeft(by: Word(exactly: rhs)!)
    }
}

extension BigUInt { // Bitwise

    static prefix func ~(a: BigUInt) -> BigUInt {
        return BigUInt(words: a.words.map { ~$0 })
    }

    static func |= (a: inout BigUInt, b: BigUInt) {
        a.reserveCapacity(b.count)
        for i in 0 ..< b.count {
            a[i] |= b[i]
        }
    }

    static func &= (a: inout BigUInt, b: BigUInt) {
        for i in 0 ..< Swift.max(a.count, b.count) {
            a[i] &= b[i]
        }
    }

    static func ^= (a: inout BigUInt, b: BigUInt) {
        a.reserveCapacity(b.count)
        for i in 0 ..< b.count {
            a[i] ^= b[i]
        }
    }
}
