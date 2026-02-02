/// Apply the `ac:` Miniscript wrapper mashup to a `K` expression.
/// - Parameters:
///   - lhs: The ``AC(_:)`` wrapper function.
///   - rhs: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpK>(lhs: @escaping (_ x: X) -> A_<C_<X>>, rhs: X) -> A_<C_<X>> { lhs(rhs) }
/// The `ac:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func AC<X: ExpK>(_ x: X) -> A_<C_<X>> { A¦C(x) }

/// Apply the `ad:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``AD(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> A_<D_<X>>, rhs: X) -> A_<D_<X>> { lhs(rhs) }
/// The `ad:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func AD<X: ExpV>(_ x: X) -> A_<D_<X>> { A¦D(x) }

/// Apply the `adv:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``ADV(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> A_<D_<V_<X>>>, rhs: X) -> A_<D_<V_<X>>> { lhs(rhs) }
/// The `adv:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ADV<X: ExpB>(_ x: X) -> A_<D_<V_<X>>> { A¦D¦V(x) }

/// Apply the `aj:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``AJ(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> A_<J_<X>>, rhs: X) -> A_<J_<X>> { lhs(rhs) }
/// The `aj:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func AJ<X: ExpB>(_ x: X) -> A_<J_<X>> { A¦J(x) }

/// Apply the `ajc:` Miniscript wrapper mashup to a `K` expression.
/// - Parameters:
///   - lhs: The ``AJC(_:)`` wrapper function.
///   - rhs: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpK>(lhs: @escaping (_ x: X) -> A_<J_<C_<X>>>, rhs: X) -> A_<J_<C_<X>>> { lhs(rhs) }
/// The `ajc:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func AJC<X: ExpK>(_ x: X) -> A_<J_<C_<X>>> { A¦J¦C(x) }

/// Apply the `ajd:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``AJD(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> A_<J_<D_<X>>>, rhs: X) -> A_<J_<D_<X>>> { lhs(rhs) }
/// The `ajd:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func AJD<X: ExpV>(_ x: X) -> A_<J_<D_<X>>> { A¦J¦D(x) }

/// Apply the `ajj:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``AJJ(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> A_<J_<J_<X>>>, rhs: X) -> A_<J_<J_<X>>> { lhs(rhs) }
/// The `ajj:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func AJJ<X: ExpB>(_ x: X) -> A_<J_<J_<X>>> { A¦J¦J(x) }

/// Apply the `ajn:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``AJN(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> A_<J_<N_<X>>>, rhs: X) -> A_<J_<N_<X>>> { lhs(rhs) }
/// The `ajn:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func AJN<X: ExpB>(_ x: X) -> A_<J_<N_<X>>> { A¦J¦N(x) }

/// Apply the `ajt:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``AJT(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> A_<J_<T_<X>>>, rhs: X) -> A_<J_<T_<X>>> { lhs(rhs) }
/// The `ajt:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func AJT<X: ExpV>(_ x: X) -> A_<J_<T_<X>>> { A¦J¦T(x) }

/// Apply the `ajl:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``AJL(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> A_<J_<L_<X>>>, rhs: X) -> A_<J_<L_<X>>> { lhs(rhs) }
/// The `ajl:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func AJL<X: ExpB>(_ x: X) -> A_<J_<L_<X>>> { A¦J¦L(x) }

/// Apply the `aju:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``AJU(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> A_<J_<U_<X>>>, rhs: X) -> A_<J_<U_<X>>> { lhs(rhs) }
/// The `aju:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func AJU<X: ExpB>(_ x: X) -> A_<J_<U_<X>>> { A¦J¦U(x) }

/// Apply the `an:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``AN(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> A_<N_<X>>, rhs: X) -> A_<N_<X>> { lhs(rhs) }
/// The `an:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func AN<X: ExpB>(_ x: X) -> A_<N_<X>> { A¦N(x) }

/// Apply the `anc:` Miniscript wrapper mashup to a `K` expression.
/// - Parameters:
///   - lhs: The ``ANC(_:)`` wrapper function.
///   - rhs: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpK>(lhs: @escaping (_ x: X) -> A_<N_<C_<X>>>, rhs: X) -> A_<N_<C_<X>>> { lhs(rhs) }
/// The `anc:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func ANC<X: ExpK>(_ x: X) -> A_<N_<C_<X>>> { A¦N¦C(x) }

/// Apply the `and:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``AND(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> A_<N_<D_<X>>>, rhs: X) -> A_<N_<D_<X>>> { lhs(rhs) }
/// The `and:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func AND<X: ExpV>(_ x: X) -> A_<N_<D_<X>>> { A¦N¦D(x) }

/// Apply the `anj:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``ANJ(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> A_<N_<J_<X>>>, rhs: X) -> A_<N_<J_<X>>> { lhs(rhs) }
/// The `anj:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ANJ<X: ExpB>(_ x: X) -> A_<N_<J_<X>>> { A¦N¦J(x) }

/// Apply the `ann:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``ANN(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> A_<N_<N_<X>>>, rhs: X) -> A_<N_<N_<X>>> { lhs(rhs) }
/// The `ann:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ANN<X: ExpB>(_ x: X) -> A_<N_<N_<X>>> { A¦N¦N(x) }

/// Apply the `ant:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``ANT(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> A_<N_<T_<X>>>, rhs: X) -> A_<N_<T_<X>>> { lhs(rhs) }
/// The `ant:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ANT<X: ExpV>(_ x: X) -> A_<N_<T_<X>>> { A¦N¦T(x) }

/// Apply the `anl:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``ANL(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> A_<N_<L_<X>>>, rhs: X) -> A_<N_<L_<X>>> { lhs(rhs) }
/// The `anl:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ANL<X: ExpB>(_ x: X) -> A_<N_<L_<X>>> { A¦N¦L(x) }

/// Apply the `anu:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``ANU(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> A_<N_<U_<X>>>, rhs: X) -> A_<N_<U_<X>>> { lhs(rhs) }
/// The `anu:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ANU<X: ExpB>(_ x: X) -> A_<N_<U_<X>>> { A¦N¦U(x) }

/// Apply the `at:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``AT(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> A_<T_<X>>, rhs: X) -> A_<T_<X>> { lhs(rhs) }
/// The `at:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func AT<X: ExpV>(_ x: X) -> A_<T_<X>> { A¦T(x) }

/// Apply the `atv:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``ATV(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> A_<T_<V_<X>>>, rhs: X) -> A_<T_<V_<X>>> { lhs(rhs) }
/// The `atv:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ATV<X: ExpB>(_ x: X) -> A_<T_<V_<X>>> { A¦T¦V(x) }

/// Apply the `al:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``AL(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> A_<L_<X>>, rhs: X) -> A_<L_<X>> { lhs(rhs) }
/// The `al:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func AL<X: ExpB>(_ x: X) -> A_<L_<X>> { A¦L(x) }

/// Apply the `alc:` Miniscript wrapper mashup to a `K` expression.
/// - Parameters:
///   - lhs: The ``ALC(_:)`` wrapper function.
///   - rhs: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpK>(lhs: @escaping (_ x: X) -> A_<L_<C_<X>>>, rhs: X) -> A_<L_<C_<X>>> { lhs(rhs) }
/// The `alc:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func ALC<X: ExpK>(_ x: X) -> A_<L_<C_<X>>> { A¦L¦C(x) }

/// Apply the `ald:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``ALD(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> A_<L_<D_<X>>>, rhs: X) -> A_<L_<D_<X>>> { lhs(rhs) }
/// The `ald:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ALD<X: ExpV>(_ x: X) -> A_<L_<D_<X>>> { A¦L¦D(x) }

/// Apply the `alj:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``ALJ(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> A_<L_<J_<X>>>, rhs: X) -> A_<L_<J_<X>>> { lhs(rhs) }
/// The `alj:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ALJ<X: ExpB>(_ x: X) -> A_<L_<J_<X>>> { A¦L¦J(x) }

/// Apply the `aln:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``ALN(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> A_<L_<N_<X>>>, rhs: X) -> A_<L_<N_<X>>> { lhs(rhs) }
/// The `aln:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ALN<X: ExpB>(_ x: X) -> A_<L_<N_<X>>> { A¦L¦N(x) }

/// Apply the `alt:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``ALT(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> A_<L_<T_<X>>>, rhs: X) -> A_<L_<T_<X>>> { lhs(rhs) }
/// The `alt:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ALT<X: ExpV>(_ x: X) -> A_<L_<T_<X>>> { A¦L¦T(x) }

/// Apply the `all:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``ALL(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> A_<L_<L_<X>>>, rhs: X) -> A_<L_<L_<X>>> { lhs(rhs) }
/// The `all:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ALL<X: ExpB>(_ x: X) -> A_<L_<L_<X>>> { A¦L¦L(x) }

/// Apply the `alu:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``ALU(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> A_<L_<U_<X>>>, rhs: X) -> A_<L_<U_<X>>> { lhs(rhs) }
/// The `alu:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ALU<X: ExpB>(_ x: X) -> A_<L_<U_<X>>> { A¦L¦U(x) }

/// Apply the `au:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``AU(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> A_<U_<X>>, rhs: X) -> A_<U_<X>> { lhs(rhs) }
/// The `au:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func AU<X: ExpB>(_ x: X) -> A_<U_<X>> { A¦U(x) }

/// Apply the `auc:` Miniscript wrapper mashup to a `K` expression.
/// - Parameters:
///   - lhs: The ``AUC(_:)`` wrapper function.
///   - rhs: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpK>(lhs: @escaping (_ x: X) -> A_<U_<C_<X>>>, rhs: X) -> A_<U_<C_<X>>> { lhs(rhs) }
/// The `auc:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func AUC<X: ExpK>(_ x: X) -> A_<U_<C_<X>>> { A¦U¦C(x) }

/// Apply the `aud:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``AUD(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> A_<U_<D_<X>>>, rhs: X) -> A_<U_<D_<X>>> { lhs(rhs) }
/// The `aud:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func AUD<X: ExpV>(_ x: X) -> A_<U_<D_<X>>> { A¦U¦D(x) }

/// Apply the `auj:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``AUJ(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> A_<U_<J_<X>>>, rhs: X) -> A_<U_<J_<X>>> { lhs(rhs) }
/// The `auj:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func AUJ<X: ExpB>(_ x: X) -> A_<U_<J_<X>>> { A¦U¦J(x) }

/// Apply the `aun:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``AUN(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> A_<U_<N_<X>>>, rhs: X) -> A_<U_<N_<X>>> { lhs(rhs) }
/// The `aun:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func AUN<X: ExpB>(_ x: X) -> A_<U_<N_<X>>> { A¦U¦N(x) }

/// Apply the `aut:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``AUT(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> A_<U_<T_<X>>>, rhs: X) -> A_<U_<T_<X>>> { lhs(rhs) }
/// The `aut:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func AUT<X: ExpV>(_ x: X) -> A_<U_<T_<X>>> { A¦U¦T(x) }

/// Apply the `aul:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``AUL(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> A_<U_<L_<X>>>, rhs: X) -> A_<U_<L_<X>>> { lhs(rhs) }
/// The `aul:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func AUL<X: ExpB>(_ x: X) -> A_<U_<L_<X>>> { A¦U¦L(x) }

/// Apply the `auu:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``AUU(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> A_<U_<U_<X>>>, rhs: X) -> A_<U_<U_<X>>> { lhs(rhs) }
/// The `auu:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func AUU<X: ExpB>(_ x: X) -> A_<U_<U_<X>>> { A¦U¦U(x) }

/// Apply the `sc:` Miniscript wrapper mashup to a `K` expression.
/// - Parameters:
///   - lhs: The ``SC(_:)`` wrapper function.
///   - rhs: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpK>(lhs: @escaping (_ x: X) -> S_<C_<X>>, rhs: X) -> S_<C_<X>> { lhs(rhs) }
/// The `sc:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func SC<X: ExpK>(_ x: X) -> S_<C_<X>> { S¦C(x) }

/// Apply the `sd:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``SD(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> S_<D_<X>>, rhs: X) -> S_<D_<X>> { lhs(rhs) }
/// The `sd:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func SD<X: ExpV>(_ x: X) -> S_<D_<X>> { S¦D(x) }

/// Apply the `sdv:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``SDV(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> S_<D_<V_<X>>>, rhs: X) -> S_<D_<V_<X>>> { lhs(rhs) }
/// The `sdv:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func SDV<X: ExpB>(_ x: X) -> S_<D_<V_<X>>> { S¦D¦V(x) }

/// Apply the `sj:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``SJ(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> S_<J_<X>>, rhs: X) -> S_<J_<X>> { lhs(rhs) }
/// The `sj:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func SJ<X: ExpB>(_ x: X) -> S_<J_<X>> { S¦J(x) }

/// Apply the `sjc:` Miniscript wrapper mashup to a `K` expression.
/// - Parameters:
///   - lhs: The ``SJC(_:)`` wrapper function.
///   - rhs: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpK>(lhs: @escaping (_ x: X) -> S_<J_<C_<X>>>, rhs: X) -> S_<J_<C_<X>>> { lhs(rhs) }
/// The `sjc:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func SJC<X: ExpK>(_ x: X) -> S_<J_<C_<X>>> { S¦J¦C(x) }

/// Apply the `sjd:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``SJD(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> S_<J_<D_<X>>>, rhs: X) -> S_<J_<D_<X>>> { lhs(rhs) }
/// The `sjd:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func SJD<X: ExpV>(_ x: X) -> S_<J_<D_<X>>> { S¦J¦D(x) }

/// Apply the `sjj:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``SJJ(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> S_<J_<J_<X>>>, rhs: X) -> S_<J_<J_<X>>> { lhs(rhs) }
/// The `sjj:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func SJJ<X: ExpB>(_ x: X) -> S_<J_<J_<X>>> { S¦J¦J(x) }

/// Apply the `sjn:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``SJN(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> S_<J_<N_<X>>>, rhs: X) -> S_<J_<N_<X>>> { lhs(rhs) }
/// The `sjn:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func SJN<X: ExpB>(_ x: X) -> S_<J_<N_<X>>> { S¦J¦N(x) }

/// Apply the `sjt:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``SJT(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> S_<J_<T_<X>>>, rhs: X) -> S_<J_<T_<X>>> { lhs(rhs) }
/// The `sjt:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func SJT<X: ExpV>(_ x: X) -> S_<J_<T_<X>>> { S¦J¦T(x) }

/// Apply the `sjl:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``SJL(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> S_<J_<L_<X>>>, rhs: X) -> S_<J_<L_<X>>> { lhs(rhs) }
/// The `sjl:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func SJL<X: ExpB>(_ x: X) -> S_<J_<L_<X>>> { S¦J¦L(x) }

/// Apply the `sju:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``SJU(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> S_<J_<U_<X>>>, rhs: X) -> S_<J_<U_<X>>> { lhs(rhs) }
/// The `sju:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func SJU<X: ExpB>(_ x: X) -> S_<J_<U_<X>>> { S¦J¦U(x) }

/// Apply the `sn:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``SN(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> S_<N_<X>>, rhs: X) -> S_<N_<X>> { lhs(rhs) }
/// The `sn:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func SN<X: ExpB>(_ x: X) -> S_<N_<X>> { S¦N(x) }

/// Apply the `snc:` Miniscript wrapper mashup to a `K` expression.
/// - Parameters:
///   - lhs: The ``SNC(_:)`` wrapper function.
///   - rhs: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpK>(lhs: @escaping (_ x: X) -> S_<N_<C_<X>>>, rhs: X) -> S_<N_<C_<X>>> { lhs(rhs) }
/// The `snc:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func SNC<X: ExpK>(_ x: X) -> S_<N_<C_<X>>> { S¦N¦C(x) }

/// Apply the `snd:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``SND(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> S_<N_<D_<X>>>, rhs: X) -> S_<N_<D_<X>>> { lhs(rhs) }
/// The `snd:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func SND<X: ExpV>(_ x: X) -> S_<N_<D_<X>>> { S¦N¦D(x) }

/// Apply the `snj:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``SNJ(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> S_<N_<J_<X>>>, rhs: X) -> S_<N_<J_<X>>> { lhs(rhs) }
/// The `snj:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func SNJ<X: ExpB>(_ x: X) -> S_<N_<J_<X>>> { S¦N¦J(x) }

/// Apply the `snn:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``SNN(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> S_<N_<N_<X>>>, rhs: X) -> S_<N_<N_<X>>> { lhs(rhs) }
/// The `snn:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func SNN<X: ExpB>(_ x: X) -> S_<N_<N_<X>>> { S¦N¦N(x) }

/// Apply the `snt:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``SNT(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> S_<N_<T_<X>>>, rhs: X) -> S_<N_<T_<X>>> { lhs(rhs) }
/// The `snt:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func SNT<X: ExpV>(_ x: X) -> S_<N_<T_<X>>> { S¦N¦T(x) }

/// Apply the `snl:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``SNL(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> S_<N_<L_<X>>>, rhs: X) -> S_<N_<L_<X>>> { lhs(rhs) }
/// The `snl:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func SNL<X: ExpB>(_ x: X) -> S_<N_<L_<X>>> { S¦N¦L(x) }

/// Apply the `snu:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``SNU(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> S_<N_<U_<X>>>, rhs: X) -> S_<N_<U_<X>>> { lhs(rhs) }
/// The `snu:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func SNU<X: ExpB>(_ x: X) -> S_<N_<U_<X>>> { S¦N¦U(x) }

/// Apply the `st:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``ST(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> S_<T_<X>>, rhs: X) -> S_<T_<X>> { lhs(rhs) }
/// The `st:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ST<X: ExpV>(_ x: X) -> S_<T_<X>> { S¦T(x) }

/// Apply the `stv:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``STV(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> S_<T_<V_<X>>>, rhs: X) -> S_<T_<V_<X>>> { lhs(rhs) }
/// The `stv:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func STV<X: ExpB>(_ x: X) -> S_<T_<V_<X>>> { S¦T¦V(x) }

/// Apply the `sl:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``SL(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> S_<L_<X>>, rhs: X) -> S_<L_<X>> { lhs(rhs) }
/// The `sl:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func SL<X: ExpB>(_ x: X) -> S_<L_<X>> { S¦L(x) }

/// Apply the `slc:` Miniscript wrapper mashup to a `K` expression.
/// - Parameters:
///   - lhs: The ``SLC(_:)`` wrapper function.
///   - rhs: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpK>(lhs: @escaping (_ x: X) -> S_<L_<C_<X>>>, rhs: X) -> S_<L_<C_<X>>> { lhs(rhs) }
/// The `slc:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func SLC<X: ExpK>(_ x: X) -> S_<L_<C_<X>>> { S¦L¦C(x) }

/// Apply the `sld:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``SLD(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> S_<L_<D_<X>>>, rhs: X) -> S_<L_<D_<X>>> { lhs(rhs) }
/// The `sld:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func SLD<X: ExpV>(_ x: X) -> S_<L_<D_<X>>> { S¦L¦D(x) }

/// Apply the `slj:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``SLJ(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> S_<L_<J_<X>>>, rhs: X) -> S_<L_<J_<X>>> { lhs(rhs) }
/// The `slj:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func SLJ<X: ExpB>(_ x: X) -> S_<L_<J_<X>>> { S¦L¦J(x) }

/// Apply the `sln:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``SLN(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> S_<L_<N_<X>>>, rhs: X) -> S_<L_<N_<X>>> { lhs(rhs) }
/// The `sln:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func SLN<X: ExpB>(_ x: X) -> S_<L_<N_<X>>> { S¦L¦N(x) }

/// Apply the `slt:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``SLT(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> S_<L_<T_<X>>>, rhs: X) -> S_<L_<T_<X>>> { lhs(rhs) }
/// The `slt:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func SLT<X: ExpV>(_ x: X) -> S_<L_<T_<X>>> { S¦L¦T(x) }

/// Apply the `sll:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``SLL(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> S_<L_<L_<X>>>, rhs: X) -> S_<L_<L_<X>>> { lhs(rhs) }
/// The `sll:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func SLL<X: ExpB>(_ x: X) -> S_<L_<L_<X>>> { S¦L¦L(x) }

/// Apply the `slu:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``SLU(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> S_<L_<U_<X>>>, rhs: X) -> S_<L_<U_<X>>> { lhs(rhs) }
/// The `slu:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func SLU<X: ExpB>(_ x: X) -> S_<L_<U_<X>>> { S¦L¦U(x) }

/// Apply the `su:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``SU(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> S_<U_<X>>, rhs: X) -> S_<U_<X>> { lhs(rhs) }
/// The `su:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func SU<X: ExpB>(_ x: X) -> S_<U_<X>> { S¦U(x) }

/// Apply the `suc:` Miniscript wrapper mashup to a `K` expression.
/// - Parameters:
///   - lhs: The ``SUC(_:)`` wrapper function.
///   - rhs: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpK>(lhs: @escaping (_ x: X) -> S_<U_<C_<X>>>, rhs: X) -> S_<U_<C_<X>>> { lhs(rhs) }
/// The `suc:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func SUC<X: ExpK>(_ x: X) -> S_<U_<C_<X>>> { S¦U¦C(x) }

/// Apply the `sud:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``SUD(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> S_<U_<D_<X>>>, rhs: X) -> S_<U_<D_<X>>> { lhs(rhs) }
/// The `sud:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func SUD<X: ExpV>(_ x: X) -> S_<U_<D_<X>>> { S¦U¦D(x) }

/// Apply the `suj:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``SUJ(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> S_<U_<J_<X>>>, rhs: X) -> S_<U_<J_<X>>> { lhs(rhs) }
/// The `suj:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func SUJ<X: ExpB>(_ x: X) -> S_<U_<J_<X>>> { S¦U¦J(x) }

/// Apply the `sun:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``SUN(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> S_<U_<N_<X>>>, rhs: X) -> S_<U_<N_<X>>> { lhs(rhs) }
/// The `sun:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func SUN<X: ExpB>(_ x: X) -> S_<U_<N_<X>>> { S¦U¦N(x) }

/// Apply the `sut:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``SUT(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> S_<U_<T_<X>>>, rhs: X) -> S_<U_<T_<X>>> { lhs(rhs) }
/// The `sut:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func SUT<X: ExpV>(_ x: X) -> S_<U_<T_<X>>> { S¦U¦T(x) }

/// Apply the `sul:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``SUL(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> S_<U_<L_<X>>>, rhs: X) -> S_<U_<L_<X>>> { lhs(rhs) }
/// The `sul:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func SUL<X: ExpB>(_ x: X) -> S_<U_<L_<X>>> { S¦U¦L(x) }

/// Apply the `suu:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``SUU(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> S_<U_<U_<X>>>, rhs: X) -> S_<U_<U_<X>>> { lhs(rhs) }
/// The `suu:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func SUU<X: ExpB>(_ x: X) -> S_<U_<U_<X>>> { S¦U¦U(x) }

/// Apply the `dv:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``DV(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> D_<V_<X>>, rhs: X) -> D_<V_<X>> { lhs(rhs) }
/// The `dv:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func DV<X: ExpB>(_ x: X) -> D_<V_<X>> { D¦V(x) }

/// Apply the `dvc:` Miniscript wrapper mashup to a `K` expression.
/// - Parameters:
///   - lhs: The ``DVC(_:)`` wrapper function.
///   - rhs: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpK>(lhs: @escaping (_ x: X) -> D_<V_<C_<X>>>, rhs: X) -> D_<V_<C_<X>>> { lhs(rhs) }
/// The `dvc:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func DVC<X: ExpK>(_ x: X) -> D_<V_<C_<X>>> { D¦V¦C(x) }

/// Apply the `dvd:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``DVD(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> D_<V_<D_<X>>>, rhs: X) -> D_<V_<D_<X>>> { lhs(rhs) }
/// The `dvd:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func DVD<X: ExpV>(_ x: X) -> D_<V_<D_<X>>> { D¦V¦D(x) }

/// Apply the `dvj:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``DVJ(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> D_<V_<J_<X>>>, rhs: X) -> D_<V_<J_<X>>> { lhs(rhs) }
/// The `dvj:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func DVJ<X: ExpB>(_ x: X) -> D_<V_<J_<X>>> { D¦V¦J(x) }

/// Apply the `dvn:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``DVN(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> D_<V_<N_<X>>>, rhs: X) -> D_<V_<N_<X>>> { lhs(rhs) }
/// The `dvn:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func DVN<X: ExpB>(_ x: X) -> D_<V_<N_<X>>> { D¦V¦N(x) }

/// Apply the `dvt:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``DVT(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> D_<V_<T_<X>>>, rhs: X) -> D_<V_<T_<X>>> { lhs(rhs) }
/// The `dvt:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func DVT<X: ExpV>(_ x: X) -> D_<V_<T_<X>>> { D¦V¦T(x) }

/// Apply the `dvl:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``DVL(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> D_<V_<L_<X>>>, rhs: X) -> D_<V_<L_<X>>> { lhs(rhs) }
/// The `dvl:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func DVL<X: ExpB>(_ x: X) -> D_<V_<L_<X>>> { D¦V¦L(x) }

/// Apply the `dvu:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``DVU(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> D_<V_<U_<X>>>, rhs: X) -> D_<V_<U_<X>>> { lhs(rhs) }
/// The `dvu:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func DVU<X: ExpB>(_ x: X) -> D_<V_<U_<X>>> { D¦V¦U(x) }

/// Apply the `vc:` Miniscript wrapper mashup to a `K` expression.
/// - Parameters:
///   - lhs: The ``VC(_:)`` wrapper function.
///   - rhs: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpK>(lhs: @escaping (_ x: X) -> V_<C_<X>>, rhs: X) -> V_<C_<X>> { lhs(rhs) }
/// The `vc:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func VC<X: ExpK>(_ x: X) -> V_<C_<X>> { V¦C(x) }

/// Apply the `vd:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``VD(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> V_<D_<X>>, rhs: X) -> V_<D_<X>> { lhs(rhs) }
/// The `vd:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func VD<X: ExpV>(_ x: X) -> V_<D_<X>> { V¦D(x) }

/// Apply the `vdv:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``VDV(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> V_<D_<V_<X>>>, rhs: X) -> V_<D_<V_<X>>> { lhs(rhs) }
/// The `vdv:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func VDV<X: ExpB>(_ x: X) -> V_<D_<V_<X>>> { V¦D¦V(x) }

/// Apply the `vj:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``VJ(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> V_<J_<X>>, rhs: X) -> V_<J_<X>> { lhs(rhs) }
/// The `vj:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func VJ<X: ExpB>(_ x: X) -> V_<J_<X>> { V¦J(x) }

/// Apply the `vjc:` Miniscript wrapper mashup to a `K` expression.
/// - Parameters:
///   - lhs: The ``VJC(_:)`` wrapper function.
///   - rhs: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpK>(lhs: @escaping (_ x: X) -> V_<J_<C_<X>>>, rhs: X) -> V_<J_<C_<X>>> { lhs(rhs) }
/// The `vjc:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func VJC<X: ExpK>(_ x: X) -> V_<J_<C_<X>>> { V¦J¦C(x) }

/// Apply the `vjd:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``VJD(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> V_<J_<D_<X>>>, rhs: X) -> V_<J_<D_<X>>> { lhs(rhs) }
/// The `vjd:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func VJD<X: ExpV>(_ x: X) -> V_<J_<D_<X>>> { V¦J¦D(x) }

/// Apply the `vjj:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``VJJ(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> V_<J_<J_<X>>>, rhs: X) -> V_<J_<J_<X>>> { lhs(rhs) }
/// The `vjj:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func VJJ<X: ExpB>(_ x: X) -> V_<J_<J_<X>>> { V¦J¦J(x) }

/// Apply the `vjn:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``VJN(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> V_<J_<N_<X>>>, rhs: X) -> V_<J_<N_<X>>> { lhs(rhs) }
/// The `vjn:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func VJN<X: ExpB>(_ x: X) -> V_<J_<N_<X>>> { V¦J¦N(x) }

/// Apply the `vjt:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``VJT(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> V_<J_<T_<X>>>, rhs: X) -> V_<J_<T_<X>>> { lhs(rhs) }
/// The `vjt:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func VJT<X: ExpV>(_ x: X) -> V_<J_<T_<X>>> { V¦J¦T(x) }

/// Apply the `vjl:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``VJL(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> V_<J_<L_<X>>>, rhs: X) -> V_<J_<L_<X>>> { lhs(rhs) }
/// The `vjl:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func VJL<X: ExpB>(_ x: X) -> V_<J_<L_<X>>> { V¦J¦L(x) }

/// Apply the `vju:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``VJU(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> V_<J_<U_<X>>>, rhs: X) -> V_<J_<U_<X>>> { lhs(rhs) }
/// The `vju:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func VJU<X: ExpB>(_ x: X) -> V_<J_<U_<X>>> { V¦J¦U(x) }

/// Apply the `vn:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``VN(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> V_<N_<X>>, rhs: X) -> V_<N_<X>> { lhs(rhs) }
/// The `vn:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func VN<X: ExpB>(_ x: X) -> V_<N_<X>> { V¦N(x) }

/// Apply the `vnc:` Miniscript wrapper mashup to a `K` expression.
/// - Parameters:
///   - lhs: The ``VNC(_:)`` wrapper function.
///   - rhs: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpK>(lhs: @escaping (_ x: X) -> V_<N_<C_<X>>>, rhs: X) -> V_<N_<C_<X>>> { lhs(rhs) }
/// The `vnc:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func VNC<X: ExpK>(_ x: X) -> V_<N_<C_<X>>> { V¦N¦C(x) }

/// Apply the `vnd:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``VND(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> V_<N_<D_<X>>>, rhs: X) -> V_<N_<D_<X>>> { lhs(rhs) }
/// The `vnd:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func VND<X: ExpV>(_ x: X) -> V_<N_<D_<X>>> { V¦N¦D(x) }

/// Apply the `vnj:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``VNJ(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> V_<N_<J_<X>>>, rhs: X) -> V_<N_<J_<X>>> { lhs(rhs) }
/// The `vnj:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func VNJ<X: ExpB>(_ x: X) -> V_<N_<J_<X>>> { V¦N¦J(x) }

/// Apply the `vnn:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``VNN(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> V_<N_<N_<X>>>, rhs: X) -> V_<N_<N_<X>>> { lhs(rhs) }
/// The `vnn:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func VNN<X: ExpB>(_ x: X) -> V_<N_<N_<X>>> { V¦N¦N(x) }

/// Apply the `vnt:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``VNT(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> V_<N_<T_<X>>>, rhs: X) -> V_<N_<T_<X>>> { lhs(rhs) }
/// The `vnt:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func VNT<X: ExpV>(_ x: X) -> V_<N_<T_<X>>> { V¦N¦T(x) }

/// Apply the `vnl:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``VNL(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> V_<N_<L_<X>>>, rhs: X) -> V_<N_<L_<X>>> { lhs(rhs) }
/// The `vnl:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func VNL<X: ExpB>(_ x: X) -> V_<N_<L_<X>>> { V¦N¦L(x) }

/// Apply the `vnu:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``VNU(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> V_<N_<U_<X>>>, rhs: X) -> V_<N_<U_<X>>> { lhs(rhs) }
/// The `vnu:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func VNU<X: ExpB>(_ x: X) -> V_<N_<U_<X>>> { V¦N¦U(x) }

/// Apply the `vt:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``VT(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> V_<T_<X>>, rhs: X) -> V_<T_<X>> { lhs(rhs) }
/// The `vt:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func VT<X: ExpV>(_ x: X) -> V_<T_<X>> { V¦T(x) }

/// Apply the `vtv:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``VTV(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> V_<T_<V_<X>>>, rhs: X) -> V_<T_<V_<X>>> { lhs(rhs) }
/// The `vtv:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func VTV<X: ExpB>(_ x: X) -> V_<T_<V_<X>>> { V¦T¦V(x) }

/// Apply the `vl:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``VL(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> V_<L_<X>>, rhs: X) -> V_<L_<X>> { lhs(rhs) }
/// The `vl:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func VL<X: ExpB>(_ x: X) -> V_<L_<X>> { V¦L(x) }

/// Apply the `vlc:` Miniscript wrapper mashup to a `K` expression.
/// - Parameters:
///   - lhs: The ``VLC(_:)`` wrapper function.
///   - rhs: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpK>(lhs: @escaping (_ x: X) -> V_<L_<C_<X>>>, rhs: X) -> V_<L_<C_<X>>> { lhs(rhs) }
/// The `vlc:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func VLC<X: ExpK>(_ x: X) -> V_<L_<C_<X>>> { V¦L¦C(x) }

/// Apply the `vld:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``VLD(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> V_<L_<D_<X>>>, rhs: X) -> V_<L_<D_<X>>> { lhs(rhs) }
/// The `vld:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func VLD<X: ExpV>(_ x: X) -> V_<L_<D_<X>>> { V¦L¦D(x) }

/// Apply the `vlj:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``VLJ(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> V_<L_<J_<X>>>, rhs: X) -> V_<L_<J_<X>>> { lhs(rhs) }
/// The `vlj:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func VLJ<X: ExpB>(_ x: X) -> V_<L_<J_<X>>> { V¦L¦J(x) }

/// Apply the `vln:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``VLN(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> V_<L_<N_<X>>>, rhs: X) -> V_<L_<N_<X>>> { lhs(rhs) }
/// The `vln:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func VLN<X: ExpB>(_ x: X) -> V_<L_<N_<X>>> { V¦L¦N(x) }

/// Apply the `vlt:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``VLT(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> V_<L_<T_<X>>>, rhs: X) -> V_<L_<T_<X>>> { lhs(rhs) }
/// The `vlt:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func VLT<X: ExpV>(_ x: X) -> V_<L_<T_<X>>> { V¦L¦T(x) }

/// Apply the `vll:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``VLL(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> V_<L_<L_<X>>>, rhs: X) -> V_<L_<L_<X>>> { lhs(rhs) }
/// The `vll:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func VLL<X: ExpB>(_ x: X) -> V_<L_<L_<X>>> { V¦L¦L(x) }

/// Apply the `vlu:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``VLU(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> V_<L_<U_<X>>>, rhs: X) -> V_<L_<U_<X>>> { lhs(rhs) }
/// The `vlu:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func VLU<X: ExpB>(_ x: X) -> V_<L_<U_<X>>> { V¦L¦U(x) }

/// Apply the `vu:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``VU(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> V_<U_<X>>, rhs: X) -> V_<U_<X>> { lhs(rhs) }
/// The `vu:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func VU<X: ExpB>(_ x: X) -> V_<U_<X>> { V¦U(x) }

/// Apply the `vuc:` Miniscript wrapper mashup to a `K` expression.
/// - Parameters:
///   - lhs: The ``VUC(_:)`` wrapper function.
///   - rhs: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpK>(lhs: @escaping (_ x: X) -> V_<U_<C_<X>>>, rhs: X) -> V_<U_<C_<X>>> { lhs(rhs) }
/// The `vuc:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func VUC<X: ExpK>(_ x: X) -> V_<U_<C_<X>>> { V¦U¦C(x) }

/// Apply the `vud:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``VUD(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> V_<U_<D_<X>>>, rhs: X) -> V_<U_<D_<X>>> { lhs(rhs) }
/// The `vud:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func VUD<X: ExpV>(_ x: X) -> V_<U_<D_<X>>> { V¦U¦D(x) }

/// Apply the `vuj:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``VUJ(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> V_<U_<J_<X>>>, rhs: X) -> V_<U_<J_<X>>> { lhs(rhs) }
/// The `vuj:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func VUJ<X: ExpB>(_ x: X) -> V_<U_<J_<X>>> { V¦U¦J(x) }

/// Apply the `vun:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``VUN(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> V_<U_<N_<X>>>, rhs: X) -> V_<U_<N_<X>>> { lhs(rhs) }
/// The `vun:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func VUN<X: ExpB>(_ x: X) -> V_<U_<N_<X>>> { V¦U¦N(x) }

/// Apply the `vut:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``VUT(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> V_<U_<T_<X>>>, rhs: X) -> V_<U_<T_<X>>> { lhs(rhs) }
/// The `vut:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func VUT<X: ExpV>(_ x: X) -> V_<U_<T_<X>>> { V¦U¦T(x) }

/// Apply the `vul:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``VUL(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> V_<U_<L_<X>>>, rhs: X) -> V_<U_<L_<X>>> { lhs(rhs) }
/// The `vul:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func VUL<X: ExpB>(_ x: X) -> V_<U_<L_<X>>> { V¦U¦L(x) }

/// Apply the `vuu:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``VUU(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> V_<U_<U_<X>>>, rhs: X) -> V_<U_<U_<X>>> { lhs(rhs) }
/// The `vuu:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func VUU<X: ExpB>(_ x: X) -> V_<U_<U_<X>>> { V¦U¦U(x) }

/// Apply the `jc:` Miniscript wrapper mashup to a `K` expression.
/// - Parameters:
///   - lhs: The ``JC(_:)`` wrapper function.
///   - rhs: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpK>(lhs: @escaping (_ x: X) -> J_<C_<X>>, rhs: X) -> J_<C_<X>> { lhs(rhs) }
/// The `jc:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func JC<X: ExpK>(_ x: X) -> J_<C_<X>> { J¦C(x) }

/// Apply the `jd:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``JD(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> J_<D_<X>>, rhs: X) -> J_<D_<X>> { lhs(rhs) }
/// The `jd:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func JD<X: ExpV>(_ x: X) -> J_<D_<X>> { J¦D(x) }

/// Apply the `jdv:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``JDV(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> J_<D_<V_<X>>>, rhs: X) -> J_<D_<V_<X>>> { lhs(rhs) }
/// The `jdv:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func JDV<X: ExpB>(_ x: X) -> J_<D_<V_<X>>> { J¦D¦V(x) }

/// Apply the `jj:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``JJ(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> J_<J_<X>>, rhs: X) -> J_<J_<X>> { lhs(rhs) }
/// The `jj:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func JJ<X: ExpB>(_ x: X) -> J_<J_<X>> { J¦J(x) }

/// Apply the `jjc:` Miniscript wrapper mashup to a `K` expression.
/// - Parameters:
///   - lhs: The ``JJC(_:)`` wrapper function.
///   - rhs: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpK>(lhs: @escaping (_ x: X) -> J_<J_<C_<X>>>, rhs: X) -> J_<J_<C_<X>>> { lhs(rhs) }
/// The `jjc:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func JJC<X: ExpK>(_ x: X) -> J_<J_<C_<X>>> { J¦J¦C(x) }

/// Apply the `jjd:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``JJD(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> J_<J_<D_<X>>>, rhs: X) -> J_<J_<D_<X>>> { lhs(rhs) }
/// The `jjd:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func JJD<X: ExpV>(_ x: X) -> J_<J_<D_<X>>> { J¦J¦D(x) }

/// Apply the `jjj:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``JJJ(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> J_<J_<J_<X>>>, rhs: X) -> J_<J_<J_<X>>> { lhs(rhs) }
/// The `jjj:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func JJJ<X: ExpB>(_ x: X) -> J_<J_<J_<X>>> { J¦J¦J(x) }

/// Apply the `jjn:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``JJN(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> J_<J_<N_<X>>>, rhs: X) -> J_<J_<N_<X>>> { lhs(rhs) }
/// The `jjn:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func JJN<X: ExpB>(_ x: X) -> J_<J_<N_<X>>> { J¦J¦N(x) }

/// Apply the `jjt:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``JJT(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> J_<J_<T_<X>>>, rhs: X) -> J_<J_<T_<X>>> { lhs(rhs) }
/// The `jjt:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func JJT<X: ExpV>(_ x: X) -> J_<J_<T_<X>>> { J¦J¦T(x) }

/// Apply the `jjl:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``JJL(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> J_<J_<L_<X>>>, rhs: X) -> J_<J_<L_<X>>> { lhs(rhs) }
/// The `jjl:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func JJL<X: ExpB>(_ x: X) -> J_<J_<L_<X>>> { J¦J¦L(x) }

/// Apply the `jju:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``JJU(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> J_<J_<U_<X>>>, rhs: X) -> J_<J_<U_<X>>> { lhs(rhs) }
/// The `jju:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func JJU<X: ExpB>(_ x: X) -> J_<J_<U_<X>>> { J¦J¦U(x) }

/// Apply the `jn:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``JN(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> J_<N_<X>>, rhs: X) -> J_<N_<X>> { lhs(rhs) }
/// The `jn:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func JN<X: ExpB>(_ x: X) -> J_<N_<X>> { J¦N(x) }

/// Apply the `jnc:` Miniscript wrapper mashup to a `K` expression.
/// - Parameters:
///   - lhs: The ``JNC(_:)`` wrapper function.
///   - rhs: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpK>(lhs: @escaping (_ x: X) -> J_<N_<C_<X>>>, rhs: X) -> J_<N_<C_<X>>> { lhs(rhs) }
/// The `jnc:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func JNC<X: ExpK>(_ x: X) -> J_<N_<C_<X>>> { J¦N¦C(x) }

/// Apply the `jnd:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``JND(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> J_<N_<D_<X>>>, rhs: X) -> J_<N_<D_<X>>> { lhs(rhs) }
/// The `jnd:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func JND<X: ExpV>(_ x: X) -> J_<N_<D_<X>>> { J¦N¦D(x) }

/// Apply the `jnj:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``JNJ(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> J_<N_<J_<X>>>, rhs: X) -> J_<N_<J_<X>>> { lhs(rhs) }
/// The `jnj:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func JNJ<X: ExpB>(_ x: X) -> J_<N_<J_<X>>> { J¦N¦J(x) }

/// Apply the `jnn:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``JNN(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> J_<N_<N_<X>>>, rhs: X) -> J_<N_<N_<X>>> { lhs(rhs) }
/// The `jnn:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func JNN<X: ExpB>(_ x: X) -> J_<N_<N_<X>>> { J¦N¦N(x) }

/// Apply the `jnt:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``JNT(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> J_<N_<T_<X>>>, rhs: X) -> J_<N_<T_<X>>> { lhs(rhs) }
/// The `jnt:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func JNT<X: ExpV>(_ x: X) -> J_<N_<T_<X>>> { J¦N¦T(x) }

/// Apply the `jnl:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``JNL(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> J_<N_<L_<X>>>, rhs: X) -> J_<N_<L_<X>>> { lhs(rhs) }
/// The `jnl:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func JNL<X: ExpB>(_ x: X) -> J_<N_<L_<X>>> { J¦N¦L(x) }

/// Apply the `jnu:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``JNU(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> J_<N_<U_<X>>>, rhs: X) -> J_<N_<U_<X>>> { lhs(rhs) }
/// The `jnu:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func JNU<X: ExpB>(_ x: X) -> J_<N_<U_<X>>> { J¦N¦U(x) }

/// Apply the `jt:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``JT(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> J_<T_<X>>, rhs: X) -> J_<T_<X>> { lhs(rhs) }
/// The `jt:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func JT<X: ExpV>(_ x: X) -> J_<T_<X>> { J¦T(x) }

/// Apply the `jtv:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``JTV(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> J_<T_<V_<X>>>, rhs: X) -> J_<T_<V_<X>>> { lhs(rhs) }
/// The `jtv:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func JTV<X: ExpB>(_ x: X) -> J_<T_<V_<X>>> { J¦T¦V(x) }

/// Apply the `jl:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``JL(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> J_<L_<X>>, rhs: X) -> J_<L_<X>> { lhs(rhs) }
/// The `jl:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func JL<X: ExpB>(_ x: X) -> J_<L_<X>> { J¦L(x) }

/// Apply the `jlc:` Miniscript wrapper mashup to a `K` expression.
/// - Parameters:
///   - lhs: The ``JLC(_:)`` wrapper function.
///   - rhs: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpK>(lhs: @escaping (_ x: X) -> J_<L_<C_<X>>>, rhs: X) -> J_<L_<C_<X>>> { lhs(rhs) }
/// The `jlc:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func JLC<X: ExpK>(_ x: X) -> J_<L_<C_<X>>> { J¦L¦C(x) }

/// Apply the `jld:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``JLD(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> J_<L_<D_<X>>>, rhs: X) -> J_<L_<D_<X>>> { lhs(rhs) }
/// The `jld:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func JLD<X: ExpV>(_ x: X) -> J_<L_<D_<X>>> { J¦L¦D(x) }

/// Apply the `jlj:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``JLJ(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> J_<L_<J_<X>>>, rhs: X) -> J_<L_<J_<X>>> { lhs(rhs) }
/// The `jlj:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func JLJ<X: ExpB>(_ x: X) -> J_<L_<J_<X>>> { J¦L¦J(x) }

/// Apply the `jln:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``JLN(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> J_<L_<N_<X>>>, rhs: X) -> J_<L_<N_<X>>> { lhs(rhs) }
/// The `jln:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func JLN<X: ExpB>(_ x: X) -> J_<L_<N_<X>>> { J¦L¦N(x) }

/// Apply the `jlt:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``JLT(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> J_<L_<T_<X>>>, rhs: X) -> J_<L_<T_<X>>> { lhs(rhs) }
/// The `jlt:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func JLT<X: ExpV>(_ x: X) -> J_<L_<T_<X>>> { J¦L¦T(x) }

/// Apply the `jll:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``JLL(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> J_<L_<L_<X>>>, rhs: X) -> J_<L_<L_<X>>> { lhs(rhs) }
/// The `jll:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func JLL<X: ExpB>(_ x: X) -> J_<L_<L_<X>>> { J¦L¦L(x) }

/// Apply the `jlu:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``JLU(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> J_<L_<U_<X>>>, rhs: X) -> J_<L_<U_<X>>> { lhs(rhs) }
/// The `jlu:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func JLU<X: ExpB>(_ x: X) -> J_<L_<U_<X>>> { J¦L¦U(x) }

/// Apply the `ju:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``JU(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> J_<U_<X>>, rhs: X) -> J_<U_<X>> { lhs(rhs) }
/// The `ju:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func JU<X: ExpB>(_ x: X) -> J_<U_<X>> { J¦U(x) }

/// Apply the `juc:` Miniscript wrapper mashup to a `K` expression.
/// - Parameters:
///   - lhs: The ``JUC(_:)`` wrapper function.
///   - rhs: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpK>(lhs: @escaping (_ x: X) -> J_<U_<C_<X>>>, rhs: X) -> J_<U_<C_<X>>> { lhs(rhs) }
/// The `juc:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func JUC<X: ExpK>(_ x: X) -> J_<U_<C_<X>>> { J¦U¦C(x) }

/// Apply the `jud:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``JUD(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> J_<U_<D_<X>>>, rhs: X) -> J_<U_<D_<X>>> { lhs(rhs) }
/// The `jud:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func JUD<X: ExpV>(_ x: X) -> J_<U_<D_<X>>> { J¦U¦D(x) }

/// Apply the `juj:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``JUJ(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> J_<U_<J_<X>>>, rhs: X) -> J_<U_<J_<X>>> { lhs(rhs) }
/// The `juj:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func JUJ<X: ExpB>(_ x: X) -> J_<U_<J_<X>>> { J¦U¦J(x) }

/// Apply the `jun:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``JUN(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> J_<U_<N_<X>>>, rhs: X) -> J_<U_<N_<X>>> { lhs(rhs) }
/// The `jun:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func JUN<X: ExpB>(_ x: X) -> J_<U_<N_<X>>> { J¦U¦N(x) }

/// Apply the `jut:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``JUT(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> J_<U_<T_<X>>>, rhs: X) -> J_<U_<T_<X>>> { lhs(rhs) }
/// The `jut:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func JUT<X: ExpV>(_ x: X) -> J_<U_<T_<X>>> { J¦U¦T(x) }

/// Apply the `jul:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``JUL(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> J_<U_<L_<X>>>, rhs: X) -> J_<U_<L_<X>>> { lhs(rhs) }
/// The `jul:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func JUL<X: ExpB>(_ x: X) -> J_<U_<L_<X>>> { J¦U¦L(x) }

/// Apply the `juu:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``JUU(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> J_<U_<U_<X>>>, rhs: X) -> J_<U_<U_<X>>> { lhs(rhs) }
/// The `juu:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func JUU<X: ExpB>(_ x: X) -> J_<U_<U_<X>>> { J¦U¦U(x) }

/// Apply the `nc:` Miniscript wrapper mashup to a `K` expression.
/// - Parameters:
///   - lhs: The ``NC(_:)`` wrapper function.
///   - rhs: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpK>(lhs: @escaping (_ x: X) -> N_<C_<X>>, rhs: X) -> N_<C_<X>> { lhs(rhs) }
/// The `nc:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func NC<X: ExpK>(_ x: X) -> N_<C_<X>> { N¦C(x) }

/// Apply the `nd:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``ND(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> N_<D_<X>>, rhs: X) -> N_<D_<X>> { lhs(rhs) }
/// The `nd:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ND<X: ExpV>(_ x: X) -> N_<D_<X>> { N¦D(x) }

/// Apply the `ndv:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``NDV(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> N_<D_<V_<X>>>, rhs: X) -> N_<D_<V_<X>>> { lhs(rhs) }
/// The `ndv:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func NDV<X: ExpB>(_ x: X) -> N_<D_<V_<X>>> { N¦D¦V(x) }

/// Apply the `nj:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``NJ(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> N_<J_<X>>, rhs: X) -> N_<J_<X>> { lhs(rhs) }
/// The `nj:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func NJ<X: ExpB>(_ x: X) -> N_<J_<X>> { N¦J(x) }

/// Apply the `njc:` Miniscript wrapper mashup to a `K` expression.
/// - Parameters:
///   - lhs: The ``NJC(_:)`` wrapper function.
///   - rhs: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpK>(lhs: @escaping (_ x: X) -> N_<J_<C_<X>>>, rhs: X) -> N_<J_<C_<X>>> { lhs(rhs) }
/// The `njc:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func NJC<X: ExpK>(_ x: X) -> N_<J_<C_<X>>> { N¦J¦C(x) }

/// Apply the `njd:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``NJD(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> N_<J_<D_<X>>>, rhs: X) -> N_<J_<D_<X>>> { lhs(rhs) }
/// The `njd:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func NJD<X: ExpV>(_ x: X) -> N_<J_<D_<X>>> { N¦J¦D(x) }

/// Apply the `njj:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``NJJ(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> N_<J_<J_<X>>>, rhs: X) -> N_<J_<J_<X>>> { lhs(rhs) }
/// The `njj:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func NJJ<X: ExpB>(_ x: X) -> N_<J_<J_<X>>> { N¦J¦J(x) }

/// Apply the `njn:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``NJN(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> N_<J_<N_<X>>>, rhs: X) -> N_<J_<N_<X>>> { lhs(rhs) }
/// The `njn:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func NJN<X: ExpB>(_ x: X) -> N_<J_<N_<X>>> { N¦J¦N(x) }

/// Apply the `njt:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``NJT(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> N_<J_<T_<X>>>, rhs: X) -> N_<J_<T_<X>>> { lhs(rhs) }
/// The `njt:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func NJT<X: ExpV>(_ x: X) -> N_<J_<T_<X>>> { N¦J¦T(x) }

/// Apply the `njl:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``NJL(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> N_<J_<L_<X>>>, rhs: X) -> N_<J_<L_<X>>> { lhs(rhs) }
/// The `njl:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func NJL<X: ExpB>(_ x: X) -> N_<J_<L_<X>>> { N¦J¦L(x) }

/// Apply the `nju:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``NJU(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> N_<J_<U_<X>>>, rhs: X) -> N_<J_<U_<X>>> { lhs(rhs) }
/// The `nju:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func NJU<X: ExpB>(_ x: X) -> N_<J_<U_<X>>> { N¦J¦U(x) }

/// Apply the `nn:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``NN(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> N_<N_<X>>, rhs: X) -> N_<N_<X>> { lhs(rhs) }
/// The `nn:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func NN<X: ExpB>(_ x: X) -> N_<N_<X>> { N¦N(x) }

/// Apply the `nnc:` Miniscript wrapper mashup to a `K` expression.
/// - Parameters:
///   - lhs: The ``NNC(_:)`` wrapper function.
///   - rhs: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpK>(lhs: @escaping (_ x: X) -> N_<N_<C_<X>>>, rhs: X) -> N_<N_<C_<X>>> { lhs(rhs) }
/// The `nnc:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func NNC<X: ExpK>(_ x: X) -> N_<N_<C_<X>>> { N¦N¦C(x) }

/// Apply the `nnd:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``NND(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> N_<N_<D_<X>>>, rhs: X) -> N_<N_<D_<X>>> { lhs(rhs) }
/// The `nnd:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func NND<X: ExpV>(_ x: X) -> N_<N_<D_<X>>> { N¦N¦D(x) }

/// Apply the `nnj:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``NNJ(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> N_<N_<J_<X>>>, rhs: X) -> N_<N_<J_<X>>> { lhs(rhs) }
/// The `nnj:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func NNJ<X: ExpB>(_ x: X) -> N_<N_<J_<X>>> { N¦N¦J(x) }

/// Apply the `nnn:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``NNN(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> N_<N_<N_<X>>>, rhs: X) -> N_<N_<N_<X>>> { lhs(rhs) }
/// The `nnn:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func NNN<X: ExpB>(_ x: X) -> N_<N_<N_<X>>> { N¦N¦N(x) }

/// Apply the `nnt:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``NNT(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> N_<N_<T_<X>>>, rhs: X) -> N_<N_<T_<X>>> { lhs(rhs) }
/// The `nnt:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func NNT<X: ExpV>(_ x: X) -> N_<N_<T_<X>>> { N¦N¦T(x) }

/// Apply the `nnl:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``NNL(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> N_<N_<L_<X>>>, rhs: X) -> N_<N_<L_<X>>> { lhs(rhs) }
/// The `nnl:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func NNL<X: ExpB>(_ x: X) -> N_<N_<L_<X>>> { N¦N¦L(x) }

/// Apply the `nnu:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``NNU(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> N_<N_<U_<X>>>, rhs: X) -> N_<N_<U_<X>>> { lhs(rhs) }
/// The `nnu:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func NNU<X: ExpB>(_ x: X) -> N_<N_<U_<X>>> { N¦N¦U(x) }

/// Apply the `nt:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``NT(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> N_<T_<X>>, rhs: X) -> N_<T_<X>> { lhs(rhs) }
/// The `nt:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func NT<X: ExpV>(_ x: X) -> N_<T_<X>> { N¦T(x) }

/// Apply the `ntv:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``NTV(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> N_<T_<V_<X>>>, rhs: X) -> N_<T_<V_<X>>> { lhs(rhs) }
/// The `ntv:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func NTV<X: ExpB>(_ x: X) -> N_<T_<V_<X>>> { N¦T¦V(x) }

/// Apply the `nl:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``NL(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> N_<L_<X>>, rhs: X) -> N_<L_<X>> { lhs(rhs) }
/// The `nl:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func NL<X: ExpB>(_ x: X) -> N_<L_<X>> { N¦L(x) }

/// Apply the `nlc:` Miniscript wrapper mashup to a `K` expression.
/// - Parameters:
///   - lhs: The ``NLC(_:)`` wrapper function.
///   - rhs: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpK>(lhs: @escaping (_ x: X) -> N_<L_<C_<X>>>, rhs: X) -> N_<L_<C_<X>>> { lhs(rhs) }
/// The `nlc:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func NLC<X: ExpK>(_ x: X) -> N_<L_<C_<X>>> { N¦L¦C(x) }

/// Apply the `nld:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``NLD(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> N_<L_<D_<X>>>, rhs: X) -> N_<L_<D_<X>>> { lhs(rhs) }
/// The `nld:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func NLD<X: ExpV>(_ x: X) -> N_<L_<D_<X>>> { N¦L¦D(x) }

/// Apply the `nlj:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``NLJ(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> N_<L_<J_<X>>>, rhs: X) -> N_<L_<J_<X>>> { lhs(rhs) }
/// The `nlj:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func NLJ<X: ExpB>(_ x: X) -> N_<L_<J_<X>>> { N¦L¦J(x) }

/// Apply the `nln:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``NLN(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> N_<L_<N_<X>>>, rhs: X) -> N_<L_<N_<X>>> { lhs(rhs) }
/// The `nln:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func NLN<X: ExpB>(_ x: X) -> N_<L_<N_<X>>> { N¦L¦N(x) }

/// Apply the `nlt:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``NLT(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> N_<L_<T_<X>>>, rhs: X) -> N_<L_<T_<X>>> { lhs(rhs) }
/// The `nlt:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func NLT<X: ExpV>(_ x: X) -> N_<L_<T_<X>>> { N¦L¦T(x) }

/// Apply the `nll:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``NLL(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> N_<L_<L_<X>>>, rhs: X) -> N_<L_<L_<X>>> { lhs(rhs) }
/// The `nll:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func NLL<X: ExpB>(_ x: X) -> N_<L_<L_<X>>> { N¦L¦L(x) }

/// Apply the `nlu:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``NLU(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> N_<L_<U_<X>>>, rhs: X) -> N_<L_<U_<X>>> { lhs(rhs) }
/// The `nlu:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func NLU<X: ExpB>(_ x: X) -> N_<L_<U_<X>>> { N¦L¦U(x) }

/// Apply the `nu:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``NU(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> N_<U_<X>>, rhs: X) -> N_<U_<X>> { lhs(rhs) }
/// The `nu:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func NU<X: ExpB>(_ x: X) -> N_<U_<X>> { N¦U(x) }

/// Apply the `nuc:` Miniscript wrapper mashup to a `K` expression.
/// - Parameters:
///   - lhs: The ``NUC(_:)`` wrapper function.
///   - rhs: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpK>(lhs: @escaping (_ x: X) -> N_<U_<C_<X>>>, rhs: X) -> N_<U_<C_<X>>> { lhs(rhs) }
/// The `nuc:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func NUC<X: ExpK>(_ x: X) -> N_<U_<C_<X>>> { N¦U¦C(x) }

/// Apply the `nud:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``NUD(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> N_<U_<D_<X>>>, rhs: X) -> N_<U_<D_<X>>> { lhs(rhs) }
/// The `nud:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func NUD<X: ExpV>(_ x: X) -> N_<U_<D_<X>>> { N¦U¦D(x) }

/// Apply the `nuj:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``NUJ(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> N_<U_<J_<X>>>, rhs: X) -> N_<U_<J_<X>>> { lhs(rhs) }
/// The `nuj:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func NUJ<X: ExpB>(_ x: X) -> N_<U_<J_<X>>> { N¦U¦J(x) }

/// Apply the `nun:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``NUN(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> N_<U_<N_<X>>>, rhs: X) -> N_<U_<N_<X>>> { lhs(rhs) }
/// The `nun:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func NUN<X: ExpB>(_ x: X) -> N_<U_<N_<X>>> { N¦U¦N(x) }

/// Apply the `nut:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``NUT(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> N_<U_<T_<X>>>, rhs: X) -> N_<U_<T_<X>>> { lhs(rhs) }
/// The `nut:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func NUT<X: ExpV>(_ x: X) -> N_<U_<T_<X>>> { N¦U¦T(x) }

/// Apply the `nul:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``NUL(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> N_<U_<L_<X>>>, rhs: X) -> N_<U_<L_<X>>> { lhs(rhs) }
/// The `nul:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func NUL<X: ExpB>(_ x: X) -> N_<U_<L_<X>>> { N¦U¦L(x) }

/// Apply the `nuu:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``NUU(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> N_<U_<U_<X>>>, rhs: X) -> N_<U_<U_<X>>> { lhs(rhs) }
/// The `nuu:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func NUU<X: ExpB>(_ x: X) -> N_<U_<U_<X>>> { N¦U¦U(x) }

/// Apply the `tv:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``TV(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> T_<V_<X>>, rhs: X) -> T_<V_<X>> { lhs(rhs) }
/// The `tv:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func TV<X: ExpB>(_ x: X) -> T_<V_<X>> { T¦V(x) }

/// Apply the `tvc:` Miniscript wrapper mashup to a `K` expression.
/// - Parameters:
///   - lhs: The ``TVC(_:)`` wrapper function.
///   - rhs: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpK>(lhs: @escaping (_ x: X) -> T_<V_<C_<X>>>, rhs: X) -> T_<V_<C_<X>>> { lhs(rhs) }
/// The `tvc:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func TVC<X: ExpK>(_ x: X) -> T_<V_<C_<X>>> { T¦V¦C(x) }

/// Apply the `tvd:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``TVD(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> T_<V_<D_<X>>>, rhs: X) -> T_<V_<D_<X>>> { lhs(rhs) }
/// The `tvd:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func TVD<X: ExpV>(_ x: X) -> T_<V_<D_<X>>> { T¦V¦D(x) }

/// Apply the `tvj:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``TVJ(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> T_<V_<J_<X>>>, rhs: X) -> T_<V_<J_<X>>> { lhs(rhs) }
/// The `tvj:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func TVJ<X: ExpB>(_ x: X) -> T_<V_<J_<X>>> { T¦V¦J(x) }

/// Apply the `tvn:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``TVN(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> T_<V_<N_<X>>>, rhs: X) -> T_<V_<N_<X>>> { lhs(rhs) }
/// The `tvn:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func TVN<X: ExpB>(_ x: X) -> T_<V_<N_<X>>> { T¦V¦N(x) }

/// Apply the `tvt:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``TVT(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> T_<V_<T_<X>>>, rhs: X) -> T_<V_<T_<X>>> { lhs(rhs) }
/// The `tvt:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func TVT<X: ExpV>(_ x: X) -> T_<V_<T_<X>>> { T¦V¦T(x) }

/// Apply the `tvl:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``TVL(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> T_<V_<L_<X>>>, rhs: X) -> T_<V_<L_<X>>> { lhs(rhs) }
/// The `tvl:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func TVL<X: ExpB>(_ x: X) -> T_<V_<L_<X>>> { T¦V¦L(x) }

/// Apply the `tvu:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``TVU(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> T_<V_<U_<X>>>, rhs: X) -> T_<V_<U_<X>>> { lhs(rhs) }
/// The `tvu:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func TVU<X: ExpB>(_ x: X) -> T_<V_<U_<X>>> { T¦V¦U(x) }

/// Apply the `lc:` Miniscript wrapper mashup to a `K` expression.
/// - Parameters:
///   - lhs: The ``LC(_:)`` wrapper function.
///   - rhs: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpK>(lhs: @escaping (_ x: X) -> L_<C_<X>>, rhs: X) -> L_<C_<X>> { lhs(rhs) }
/// The `lc:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func LC<X: ExpK>(_ x: X) -> L_<C_<X>> { L¦C(x) }

/// Apply the `ld:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``LD(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> L_<D_<X>>, rhs: X) -> L_<D_<X>> { lhs(rhs) }
/// The `ld:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func LD<X: ExpV>(_ x: X) -> L_<D_<X>> { L¦D(x) }

/// Apply the `ldv:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``LDV(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> L_<D_<V_<X>>>, rhs: X) -> L_<D_<V_<X>>> { lhs(rhs) }
/// The `ldv:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func LDV<X: ExpB>(_ x: X) -> L_<D_<V_<X>>> { L¦D¦V(x) }

/// Apply the `lj:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``LJ(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> L_<J_<X>>, rhs: X) -> L_<J_<X>> { lhs(rhs) }
/// The `lj:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func LJ<X: ExpB>(_ x: X) -> L_<J_<X>> { L¦J(x) }

/// Apply the `ljc:` Miniscript wrapper mashup to a `K` expression.
/// - Parameters:
///   - lhs: The ``LJC(_:)`` wrapper function.
///   - rhs: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpK>(lhs: @escaping (_ x: X) -> L_<J_<C_<X>>>, rhs: X) -> L_<J_<C_<X>>> { lhs(rhs) }
/// The `ljc:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func LJC<X: ExpK>(_ x: X) -> L_<J_<C_<X>>> { L¦J¦C(x) }

/// Apply the `ljd:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``LJD(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> L_<J_<D_<X>>>, rhs: X) -> L_<J_<D_<X>>> { lhs(rhs) }
/// The `ljd:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func LJD<X: ExpV>(_ x: X) -> L_<J_<D_<X>>> { L¦J¦D(x) }

/// Apply the `ljj:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``LJJ(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> L_<J_<J_<X>>>, rhs: X) -> L_<J_<J_<X>>> { lhs(rhs) }
/// The `ljj:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func LJJ<X: ExpB>(_ x: X) -> L_<J_<J_<X>>> { L¦J¦J(x) }

/// Apply the `ljn:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``LJN(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> L_<J_<N_<X>>>, rhs: X) -> L_<J_<N_<X>>> { lhs(rhs) }
/// The `ljn:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func LJN<X: ExpB>(_ x: X) -> L_<J_<N_<X>>> { L¦J¦N(x) }

/// Apply the `ljt:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``LJT(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> L_<J_<T_<X>>>, rhs: X) -> L_<J_<T_<X>>> { lhs(rhs) }
/// The `ljt:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func LJT<X: ExpV>(_ x: X) -> L_<J_<T_<X>>> { L¦J¦T(x) }

/// Apply the `ljl:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``LJL(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> L_<J_<L_<X>>>, rhs: X) -> L_<J_<L_<X>>> { lhs(rhs) }
/// The `ljl:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func LJL<X: ExpB>(_ x: X) -> L_<J_<L_<X>>> { L¦J¦L(x) }

/// Apply the `lju:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``LJU(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> L_<J_<U_<X>>>, rhs: X) -> L_<J_<U_<X>>> { lhs(rhs) }
/// The `lju:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func LJU<X: ExpB>(_ x: X) -> L_<J_<U_<X>>> { L¦J¦U(x) }

/// Apply the `ln:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``LN(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> L_<N_<X>>, rhs: X) -> L_<N_<X>> { lhs(rhs) }
/// The `ln:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func LN<X: ExpB>(_ x: X) -> L_<N_<X>> { L¦N(x) }

/// Apply the `lnc:` Miniscript wrapper mashup to a `K` expression.
/// - Parameters:
///   - lhs: The ``LNC(_:)`` wrapper function.
///   - rhs: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpK>(lhs: @escaping (_ x: X) -> L_<N_<C_<X>>>, rhs: X) -> L_<N_<C_<X>>> { lhs(rhs) }
/// The `lnc:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func LNC<X: ExpK>(_ x: X) -> L_<N_<C_<X>>> { L¦N¦C(x) }

/// Apply the `lnd:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``LND(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> L_<N_<D_<X>>>, rhs: X) -> L_<N_<D_<X>>> { lhs(rhs) }
/// The `lnd:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func LND<X: ExpV>(_ x: X) -> L_<N_<D_<X>>> { L¦N¦D(x) }

/// Apply the `lnj:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``LNJ(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> L_<N_<J_<X>>>, rhs: X) -> L_<N_<J_<X>>> { lhs(rhs) }
/// The `lnj:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func LNJ<X: ExpB>(_ x: X) -> L_<N_<J_<X>>> { L¦N¦J(x) }

/// Apply the `lnn:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``LNN(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> L_<N_<N_<X>>>, rhs: X) -> L_<N_<N_<X>>> { lhs(rhs) }
/// The `lnn:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func LNN<X: ExpB>(_ x: X) -> L_<N_<N_<X>>> { L¦N¦N(x) }

/// Apply the `lnt:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``LNT(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> L_<N_<T_<X>>>, rhs: X) -> L_<N_<T_<X>>> { lhs(rhs) }
/// The `lnt:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func LNT<X: ExpV>(_ x: X) -> L_<N_<T_<X>>> { L¦N¦T(x) }

/// Apply the `lnl:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``LNL(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> L_<N_<L_<X>>>, rhs: X) -> L_<N_<L_<X>>> { lhs(rhs) }
/// The `lnl:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func LNL<X: ExpB>(_ x: X) -> L_<N_<L_<X>>> { L¦N¦L(x) }

/// Apply the `lnu:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``LNU(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> L_<N_<U_<X>>>, rhs: X) -> L_<N_<U_<X>>> { lhs(rhs) }
/// The `lnu:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func LNU<X: ExpB>(_ x: X) -> L_<N_<U_<X>>> { L¦N¦U(x) }

/// Apply the `lt:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``LT(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> L_<T_<X>>, rhs: X) -> L_<T_<X>> { lhs(rhs) }
/// The `lt:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func LT<X: ExpV>(_ x: X) -> L_<T_<X>> { L¦T(x) }

/// Apply the `ltv:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``LTV(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> L_<T_<V_<X>>>, rhs: X) -> L_<T_<V_<X>>> { lhs(rhs) }
/// The `ltv:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func LTV<X: ExpB>(_ x: X) -> L_<T_<V_<X>>> { L¦T¦V(x) }

/// Apply the `ll:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``LL(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> L_<L_<X>>, rhs: X) -> L_<L_<X>> { lhs(rhs) }
/// The `ll:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func LL<X: ExpB>(_ x: X) -> L_<L_<X>> { L¦L(x) }

/// Apply the `llc:` Miniscript wrapper mashup to a `K` expression.
/// - Parameters:
///   - lhs: The ``LLC(_:)`` wrapper function.
///   - rhs: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpK>(lhs: @escaping (_ x: X) -> L_<L_<C_<X>>>, rhs: X) -> L_<L_<C_<X>>> { lhs(rhs) }
/// The `llc:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func LLC<X: ExpK>(_ x: X) -> L_<L_<C_<X>>> { L¦L¦C(x) }

/// Apply the `lld:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``LLD(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> L_<L_<D_<X>>>, rhs: X) -> L_<L_<D_<X>>> { lhs(rhs) }
/// The `lld:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func LLD<X: ExpV>(_ x: X) -> L_<L_<D_<X>>> { L¦L¦D(x) }

/// Apply the `llj:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``LLJ(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> L_<L_<J_<X>>>, rhs: X) -> L_<L_<J_<X>>> { lhs(rhs) }
/// The `llj:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func LLJ<X: ExpB>(_ x: X) -> L_<L_<J_<X>>> { L¦L¦J(x) }

/// Apply the `lln:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``LLN(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> L_<L_<N_<X>>>, rhs: X) -> L_<L_<N_<X>>> { lhs(rhs) }
/// The `lln:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func LLN<X: ExpB>(_ x: X) -> L_<L_<N_<X>>> { L¦L¦N(x) }

/// Apply the `llt:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``LLT(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> L_<L_<T_<X>>>, rhs: X) -> L_<L_<T_<X>>> { lhs(rhs) }
/// The `llt:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func LLT<X: ExpV>(_ x: X) -> L_<L_<T_<X>>> { L¦L¦T(x) }

/// Apply the `lll:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``LLL(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> L_<L_<L_<X>>>, rhs: X) -> L_<L_<L_<X>>> { lhs(rhs) }
/// The `lll:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func LLL<X: ExpB>(_ x: X) -> L_<L_<L_<X>>> { L¦L¦L(x) }

/// Apply the `llu:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``LLU(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> L_<L_<U_<X>>>, rhs: X) -> L_<L_<U_<X>>> { lhs(rhs) }
/// The `llu:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func LLU<X: ExpB>(_ x: X) -> L_<L_<U_<X>>> { L¦L¦U(x) }

/// Apply the `lu:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``LU(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> L_<U_<X>>, rhs: X) -> L_<U_<X>> { lhs(rhs) }
/// The `lu:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func LU<X: ExpB>(_ x: X) -> L_<U_<X>> { L¦U(x) }

/// Apply the `luc:` Miniscript wrapper mashup to a `K` expression.
/// - Parameters:
///   - lhs: The ``LUC(_:)`` wrapper function.
///   - rhs: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpK>(lhs: @escaping (_ x: X) -> L_<U_<C_<X>>>, rhs: X) -> L_<U_<C_<X>>> { lhs(rhs) }
/// The `luc:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func LUC<X: ExpK>(_ x: X) -> L_<U_<C_<X>>> { L¦U¦C(x) }

/// Apply the `lud:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``LUD(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> L_<U_<D_<X>>>, rhs: X) -> L_<U_<D_<X>>> { lhs(rhs) }
/// The `lud:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func LUD<X: ExpV>(_ x: X) -> L_<U_<D_<X>>> { L¦U¦D(x) }

/// Apply the `luj:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``LUJ(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> L_<U_<J_<X>>>, rhs: X) -> L_<U_<J_<X>>> { lhs(rhs) }
/// The `luj:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func LUJ<X: ExpB>(_ x: X) -> L_<U_<J_<X>>> { L¦U¦J(x) }

/// Apply the `lun:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``LUN(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> L_<U_<N_<X>>>, rhs: X) -> L_<U_<N_<X>>> { lhs(rhs) }
/// The `lun:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func LUN<X: ExpB>(_ x: X) -> L_<U_<N_<X>>> { L¦U¦N(x) }

/// Apply the `lut:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``LUT(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> L_<U_<T_<X>>>, rhs: X) -> L_<U_<T_<X>>> { lhs(rhs) }
/// The `lut:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func LUT<X: ExpV>(_ x: X) -> L_<U_<T_<X>>> { L¦U¦T(x) }

/// Apply the `lul:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``LUL(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> L_<U_<L_<X>>>, rhs: X) -> L_<U_<L_<X>>> { lhs(rhs) }
/// The `lul:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func LUL<X: ExpB>(_ x: X) -> L_<U_<L_<X>>> { L¦U¦L(x) }

/// Apply the `luu:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``LUU(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> L_<U_<U_<X>>>, rhs: X) -> L_<U_<U_<X>>> { lhs(rhs) }
/// The `luu:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func LUU<X: ExpB>(_ x: X) -> L_<U_<U_<X>>> { L¦U¦U(x) }

/// Apply the `uc:` Miniscript wrapper mashup to a `K` expression.
/// - Parameters:
///   - lhs: The ``UC(_:)`` wrapper function.
///   - rhs: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpK>(lhs: @escaping (_ x: X) -> U_<C_<X>>, rhs: X) -> U_<C_<X>> { lhs(rhs) }
/// The `uc:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func UC<X: ExpK>(_ x: X) -> U_<C_<X>> { U¦C(x) }

/// Apply the `ud:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``UD(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> U_<D_<X>>, rhs: X) -> U_<D_<X>> { lhs(rhs) }
/// The `ud:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func UD<X: ExpV>(_ x: X) -> U_<D_<X>> { U¦D(x) }

/// Apply the `udv:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``UDV(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> U_<D_<V_<X>>>, rhs: X) -> U_<D_<V_<X>>> { lhs(rhs) }
/// The `udv:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func UDV<X: ExpB>(_ x: X) -> U_<D_<V_<X>>> { U¦D¦V(x) }

/// Apply the `uj:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``UJ(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> U_<J_<X>>, rhs: X) -> U_<J_<X>> { lhs(rhs) }
/// The `uj:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func UJ<X: ExpB>(_ x: X) -> U_<J_<X>> { U¦J(x) }

/// Apply the `ujc:` Miniscript wrapper mashup to a `K` expression.
/// - Parameters:
///   - lhs: The ``UJC(_:)`` wrapper function.
///   - rhs: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpK>(lhs: @escaping (_ x: X) -> U_<J_<C_<X>>>, rhs: X) -> U_<J_<C_<X>>> { lhs(rhs) }
/// The `ujc:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func UJC<X: ExpK>(_ x: X) -> U_<J_<C_<X>>> { U¦J¦C(x) }

/// Apply the `ujd:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``UJD(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> U_<J_<D_<X>>>, rhs: X) -> U_<J_<D_<X>>> { lhs(rhs) }
/// The `ujd:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func UJD<X: ExpV>(_ x: X) -> U_<J_<D_<X>>> { U¦J¦D(x) }

/// Apply the `ujj:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``UJJ(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> U_<J_<J_<X>>>, rhs: X) -> U_<J_<J_<X>>> { lhs(rhs) }
/// The `ujj:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func UJJ<X: ExpB>(_ x: X) -> U_<J_<J_<X>>> { U¦J¦J(x) }

/// Apply the `ujn:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``UJN(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> U_<J_<N_<X>>>, rhs: X) -> U_<J_<N_<X>>> { lhs(rhs) }
/// The `ujn:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func UJN<X: ExpB>(_ x: X) -> U_<J_<N_<X>>> { U¦J¦N(x) }

/// Apply the `ujt:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``UJT(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> U_<J_<T_<X>>>, rhs: X) -> U_<J_<T_<X>>> { lhs(rhs) }
/// The `ujt:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func UJT<X: ExpV>(_ x: X) -> U_<J_<T_<X>>> { U¦J¦T(x) }

/// Apply the `ujl:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``UJL(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> U_<J_<L_<X>>>, rhs: X) -> U_<J_<L_<X>>> { lhs(rhs) }
/// The `ujl:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func UJL<X: ExpB>(_ x: X) -> U_<J_<L_<X>>> { U¦J¦L(x) }

/// Apply the `uju:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``UJU(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> U_<J_<U_<X>>>, rhs: X) -> U_<J_<U_<X>>> { lhs(rhs) }
/// The `uju:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func UJU<X: ExpB>(_ x: X) -> U_<J_<U_<X>>> { U¦J¦U(x) }

/// Apply the `un:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``UN(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> U_<N_<X>>, rhs: X) -> U_<N_<X>> { lhs(rhs) }
/// The `un:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func UN<X: ExpB>(_ x: X) -> U_<N_<X>> { U¦N(x) }

/// Apply the `unc:` Miniscript wrapper mashup to a `K` expression.
/// - Parameters:
///   - lhs: The ``UNC(_:)`` wrapper function.
///   - rhs: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpK>(lhs: @escaping (_ x: X) -> U_<N_<C_<X>>>, rhs: X) -> U_<N_<C_<X>>> { lhs(rhs) }
/// The `unc:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func UNC<X: ExpK>(_ x: X) -> U_<N_<C_<X>>> { U¦N¦C(x) }

/// Apply the `und:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``UND(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> U_<N_<D_<X>>>, rhs: X) -> U_<N_<D_<X>>> { lhs(rhs) }
/// The `und:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func UND<X: ExpV>(_ x: X) -> U_<N_<D_<X>>> { U¦N¦D(x) }

/// Apply the `unj:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``UNJ(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> U_<N_<J_<X>>>, rhs: X) -> U_<N_<J_<X>>> { lhs(rhs) }
/// The `unj:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func UNJ<X: ExpB>(_ x: X) -> U_<N_<J_<X>>> { U¦N¦J(x) }

/// Apply the `unn:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``UNN(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> U_<N_<N_<X>>>, rhs: X) -> U_<N_<N_<X>>> { lhs(rhs) }
/// The `unn:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func UNN<X: ExpB>(_ x: X) -> U_<N_<N_<X>>> { U¦N¦N(x) }

/// Apply the `unt:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``UNT(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> U_<N_<T_<X>>>, rhs: X) -> U_<N_<T_<X>>> { lhs(rhs) }
/// The `unt:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func UNT<X: ExpV>(_ x: X) -> U_<N_<T_<X>>> { U¦N¦T(x) }

/// Apply the `unl:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``UNL(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> U_<N_<L_<X>>>, rhs: X) -> U_<N_<L_<X>>> { lhs(rhs) }
/// The `unl:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func UNL<X: ExpB>(_ x: X) -> U_<N_<L_<X>>> { U¦N¦L(x) }

/// Apply the `unu:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``UNU(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> U_<N_<U_<X>>>, rhs: X) -> U_<N_<U_<X>>> { lhs(rhs) }
/// The `unu:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func UNU<X: ExpB>(_ x: X) -> U_<N_<U_<X>>> { U¦N¦U(x) }

/// Apply the `ut:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``UT(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> U_<T_<X>>, rhs: X) -> U_<T_<X>> { lhs(rhs) }
/// The `ut:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func UT<X: ExpV>(_ x: X) -> U_<T_<X>> { U¦T(x) }

/// Apply the `utv:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``UTV(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> U_<T_<V_<X>>>, rhs: X) -> U_<T_<V_<X>>> { lhs(rhs) }
/// The `utv:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func UTV<X: ExpB>(_ x: X) -> U_<T_<V_<X>>> { U¦T¦V(x) }

/// Apply the `ul:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``UL(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> U_<L_<X>>, rhs: X) -> U_<L_<X>> { lhs(rhs) }
/// The `ul:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func UL<X: ExpB>(_ x: X) -> U_<L_<X>> { U¦L(x) }

/// Apply the `ulc:` Miniscript wrapper mashup to a `K` expression.
/// - Parameters:
///   - lhs: The ``ULC(_:)`` wrapper function.
///   - rhs: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpK>(lhs: @escaping (_ x: X) -> U_<L_<C_<X>>>, rhs: X) -> U_<L_<C_<X>>> { lhs(rhs) }
/// The `ulc:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func ULC<X: ExpK>(_ x: X) -> U_<L_<C_<X>>> { U¦L¦C(x) }

/// Apply the `uld:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``ULD(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> U_<L_<D_<X>>>, rhs: X) -> U_<L_<D_<X>>> { lhs(rhs) }
/// The `uld:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ULD<X: ExpV>(_ x: X) -> U_<L_<D_<X>>> { U¦L¦D(x) }

/// Apply the `ulj:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``ULJ(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> U_<L_<J_<X>>>, rhs: X) -> U_<L_<J_<X>>> { lhs(rhs) }
/// The `ulj:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ULJ<X: ExpB>(_ x: X) -> U_<L_<J_<X>>> { U¦L¦J(x) }

/// Apply the `uln:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``ULN(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> U_<L_<N_<X>>>, rhs: X) -> U_<L_<N_<X>>> { lhs(rhs) }
/// The `uln:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ULN<X: ExpB>(_ x: X) -> U_<L_<N_<X>>> { U¦L¦N(x) }

/// Apply the `ult:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``ULT(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> U_<L_<T_<X>>>, rhs: X) -> U_<L_<T_<X>>> { lhs(rhs) }
/// The `ult:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ULT<X: ExpV>(_ x: X) -> U_<L_<T_<X>>> { U¦L¦T(x) }

/// Apply the `ull:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``ULL(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> U_<L_<L_<X>>>, rhs: X) -> U_<L_<L_<X>>> { lhs(rhs) }
/// The `ull:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ULL<X: ExpB>(_ x: X) -> U_<L_<L_<X>>> { U¦L¦L(x) }

/// Apply the `ulu:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``ULU(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> U_<L_<U_<X>>>, rhs: X) -> U_<L_<U_<X>>> { lhs(rhs) }
/// The `ulu:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ULU<X: ExpB>(_ x: X) -> U_<L_<U_<X>>> { U¦L¦U(x) }

/// Apply the `uu:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``UU(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> U_<U_<X>>, rhs: X) -> U_<U_<X>> { lhs(rhs) }
/// The `uu:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func UU<X: ExpB>(_ x: X) -> U_<U_<X>> { U¦U(x) }

/// Apply the `uuc:` Miniscript wrapper mashup to a `K` expression.
/// - Parameters:
///   - lhs: The ``UUC(_:)`` wrapper function.
///   - rhs: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpK>(lhs: @escaping (_ x: X) -> U_<U_<C_<X>>>, rhs: X) -> U_<U_<C_<X>>> { lhs(rhs) }
/// The `uuc:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpK`` expression.
/// - Returns: The wrapped expression.
public func UUC<X: ExpK>(_ x: X) -> U_<U_<C_<X>>> { U¦U¦C(x) }

/// Apply the `uud:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``UUD(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> U_<U_<D_<X>>>, rhs: X) -> U_<U_<D_<X>>> { lhs(rhs) }
/// The `uud:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func UUD<X: ExpV>(_ x: X) -> U_<U_<D_<X>>> { U¦U¦D(x) }

/// Apply the `uuj:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``UUJ(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> U_<U_<J_<X>>>, rhs: X) -> U_<U_<J_<X>>> { lhs(rhs) }
/// The `uuj:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func UUJ<X: ExpB>(_ x: X) -> U_<U_<J_<X>>> { U¦U¦J(x) }

/// Apply the `uun:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``UUN(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> U_<U_<N_<X>>>, rhs: X) -> U_<U_<N_<X>>> { lhs(rhs) }
/// The `uun:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func UUN<X: ExpB>(_ x: X) -> U_<U_<N_<X>>> { U¦U¦N(x) }

/// Apply the `uut:` Miniscript wrapper mashup to a `V` expression.
/// - Parameters:
///   - lhs: The ``UUT(_:)`` wrapper function.
///   - rhs: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpV>(lhs: @escaping (_ x: X) -> U_<U_<T_<X>>>, rhs: X) -> U_<U_<T_<X>>> { lhs(rhs) }
/// The `uut:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpV`` expression.
/// - Returns: The wrapped expression.
public func UUT<X: ExpV>(_ x: X) -> U_<U_<T_<X>>> { U¦U¦T(x) }

/// Apply the `uul:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``UUL(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> U_<U_<L_<X>>>, rhs: X) -> U_<U_<L_<X>>> { lhs(rhs) }
/// The `uul:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func UUL<X: ExpB>(_ x: X) -> U_<U_<L_<X>>> { U¦U¦L(x) }

/// Apply the `uuu:` Miniscript wrapper mashup to a `B` expression.
/// - Parameters:
///   - lhs: The ``UUU(_:)`` wrapper function.
///   - rhs: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func ¦<X: ExpB>(lhs: @escaping (_ x: X) -> U_<U_<U_<X>>>, rhs: X) -> U_<U_<U_<X>>> { lhs(rhs) }
/// The `uuu:` Miniscript wrapper mashup.
/// - Parameter x: The input ``ExpB`` expression.
/// - Returns: The wrapped expression.
public func UUU<X: ExpB>(_ x: X) -> U_<U_<U_<X>>> { U¦U¦U(x) }

