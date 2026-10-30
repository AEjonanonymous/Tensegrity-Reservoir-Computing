import Mathlib

open Matrix

variable {N M : ℕ}
variable (G : Fin M → Matrix (Fin (3 * N)) (Fin (3 * N)) ℝ)

def Kg (t0 : Fin M → ℝ) : Matrix (Fin (3 * N)) (Fin (3 * N)) ℝ :=
  ∑ k : Fin M, t0 k • G k

theorem Kg_add (a b : Fin M → ℝ) : Kg G (a + b) = Kg G a + Kg G b := by sorry

theorem Kg_smul (c : ℝ) (t0 : Fin M → ℝ) : Kg G (c • t0) = c • Kg G t0 := by sorry

def KgLinearMap : (Fin M → ℝ) →ₗ[ℝ] Matrix (Fin (3 * N)) (Fin (3 * N)) ℝ where
    toFun := Kg G
    map_add' := Kg_add G
    map_smul' := Kg_smul G

def TensegrityCone (cables struts : Finset (Fin M)) (t0 : Fin M → ℝ) : Prop :=
  (∀ k ∈ cables, 0 < t0 k) ∧ (∀ k ∈ struts, t0 k < 0)

theorem tensegrity_cone_convex (cables struts : Finset (Fin M)) 
    (u v : Fin M → ℝ) (hu : TensegrityCone cables struts u) 
    (hv : TensegrityCone cables struts v) (a b : ℝ) (ha : 0 ≤ a) (hb : 0 ≤ b) (hab : a + b = 1) :
    TensegrityCone cables struts (fun k => a * u k + b * v k) := by sorry

def memberSensitivity (G_k : Matrix (Fin (3 * N)) (Fin (3 * N)) ℝ) (phi : Fin (3 * N) → ℝ) : ℝ :=
  dotProduct phi (G_k.mulVec phi)

theorem sensitivity_linear (G1 G2 : Matrix (Fin (3 * N)) (Fin (3 * N)) ℝ) (phi : Fin (3 * N) → ℝ) (c : ℝ) :
    memberSensitivity (G1 + c • G2) phi = memberSensitivity G1 phi + c * memberSensitivity G2 phi := by sorry

theorem sensitivity_bounded_expansion 
    (G_k : Matrix (Fin (3 * N)) (Fin (3 * N)) ℝ) (phi : Fin (3 * N) → ℝ) 
    (B : ℝ) (hB : ∀ i j, abs (G_k i j) ≤ B) :
    abs (memberSensitivity G_k phi) ≤ 
      ∑ i : Fin (3 * N), ∑ j : Fin (3 * N), abs (phi i) * B * abs (phi j) := by sorry

def tangentStiffness (Ke Kg_matrix : Matrix (Fin (3 * N)) (Fin (3 * N)) ℝ) : Matrix (Fin (3 * N)) (Fin (3 * N)) ℝ :=
  Ke + Kg_matrix

def IsPositiveDefinite (K : Matrix (Fin (3 * N)) (Fin (3 * N)) ℝ) : Prop :=
  ∀ v : Fin (3 * N) → ℝ, (∃ i, v i ≠ 0) → 0 < dotProduct v (K.mulVec v)

theorem dynamic_stability_positive_definiteness 
    (Ke Kg_matrix : Matrix (Fin (3 * N)) (Fin (3 * N)) ℝ)
    (hKe : IsPositiveDefinite Ke)
    (hKg_bound : ∀ v, 0 ≤ dotProduct v (Kg_matrix.mulVec v)) :
    IsPositiveDefinite (tangentStiffness Ke Kg_matrix) := by sorry