func pythonTrueModulo(_ a: Int, _ b: Int) -> Int {
    let remainder = a % b
    return remainder >= 0 ? remainder : remainder + b
}
