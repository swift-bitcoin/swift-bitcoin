public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> S_<L_<N_<X>>>, rhs: X) -> S_<L_<N_<X>>> { lhs(rhs) }
public func SLN<X: ExpB>(_ x: X) -> S_<L_<N_<X>>> { S¦L¦N(x) }

// TODO: Generate remaining valid combinations using Swift Plugin or Swift Macro. e.g. `#validWrapperPermutations(S, L, N)`
