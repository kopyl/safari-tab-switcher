import Foundation

class Array2D {
    var cols: Int, rows: Int
    var matrix: [Int]

    init(cols: Int, rows: Int) {
        self.cols = cols
        self.rows = rows
        matrix = Array(repeating: 0, count: cols * rows)
    }

    subscript(col: Int, row: Int) -> Int {
        get {
            precondition(col >= 0 && col < cols, "Column index out of bounds")
            precondition(row >= 0 && row < rows, "Row index out of bounds")
            return matrix[cols * row + col]
        }
        set {
            precondition(col >= 0 && col < cols, "Column index out of bounds")
            precondition(row >= 0 && row < rows, "Row index out of bounds")
            matrix[cols * row + col] = newValue
        }
    }

    func colCount() -> Int { return cols }
    func rowCount() -> Int { return rows }
}

class LevenshteinDistance {
    static func get(_ aStr: String, _ bStr: String) -> Int {
        let a = Array(aStr.utf16)
        let b = Array(bStr.utf16)

        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }

        let dist = Array2D(cols: a.count + 1, rows: b.count + 1)

        for i in 0...a.count {
            dist[i, 0] = i
        }

        for j in 0...b.count {
            dist[0, j] = j
        }

        for i in 1...a.count {
            for j in 1...b.count {
                if a[i-1] == b[j-1] {
                    dist[i, j] = dist[i-1, j-1]
                } else {
                    dist[i, j] = Swift.min(
                        dist[i-1, j] + 1,
                        dist[i, j-1] + 1,
                        dist[i-1, j-1] + 1
                    )
                }
            }
        }

        return dist[a.count, b.count]
    }
}
