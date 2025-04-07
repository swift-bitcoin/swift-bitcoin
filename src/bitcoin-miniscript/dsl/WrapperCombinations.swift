public func ~<X: ExpB>(lhs: @escaping (_ x: X) -> S_<L_<N_<X>>>, rhs: X) -> S_<L_<N_<X>>> { lhs(rhs) }
public func SLN<X: ExpB>(_ x: X) -> S_<L_<N_<X>>> { S_(L_(N_(x))) }

// TODO: Generate remaining valid combinations
