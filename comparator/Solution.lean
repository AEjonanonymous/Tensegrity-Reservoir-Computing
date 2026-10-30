import Mathlib

open Matrix

variable {N M : ℕ}
variable (G : Fin M → Matrix (Fin (3 * N)) (Fin (3 * N)) ℝ)

def Kg (t0 : Fin M → ℝ) : Matrix (Fin (3 * N)) (Fin (3 * N)) ℝ :=
  ∑ k : Fin M, t0 k • G k

theorem Kg_add (a b : Fin M → ℝ) : Kg G (a + b) = Kg G a + Kg G b := by
  dsimp [Kg]
  simp [add_smul, Finset.sum_add_distrib]

theorem Kg_smul (c : ℝ) (t0 : Fin M → ℝ) : Kg G (c • t0) = c • Kg G t0 := by
  dsimp [Kg]
  rw [Finset.smul_sum]
  apply Finset.sum_congr rfl
  intro k _
  simp [mul_smul]

def KgLinearMap : (Fin M → ℝ) →ₗ[ℝ] Matrix (Fin (3 * N)) (Fin (3 * N)) ℝ where
    toFun := Kg G
    map_add' := Kg_add G
    map_smul' := Kg_smul G

def TensegrityCone (cables struts : Finset (Fin M)) (t0 : Fin M → ℝ) : Prop :=
  (∀ k ∈ cables, 0 < t0 k) ∧ (∀ k ∈ struts, t0 k < 0)

theorem tensegrity_cone_convex (cables struts : Finset (Fin M)) 
    (u v : Fin M → ℝ) (hu : TensegrityCone cables struts u) 
    (hv : TensegrityCone cables struts v) (a b : ℝ) (ha : 0 ≤ a) (hb : 0 ≤ b) (hab : a + b = 1) :
    TensegrityCone cables struts (fun k => a * u k + b * v k) := by
  constructor
  · intro k hk
    have hu_pos := hu.1 k hk
    have hv_pos := hv.1 k hk
    have h1 : 0 ≤ a * u k := mul_nonneg ha (le_of_lt hu_pos)
    have h2 : 0 ≤ b * v k := mul_nonneg hb (le_of_lt hv_pos)
    by_contra h_not
    have h_sum_le : a * u k + b * v k ≤ 0 := by linarith
    have ha0 : a * u k = 0 := by nlinarith
    have hb0 : b * v k = 0 := by nlinarith
    cases' mul_eq_zero.mp ha0 with ha_zero ha_uk
    · cases' mul_eq_zero.mp hb0 with hb_zero hb_vk
      · linarith [ha_zero, hb_zero, hab]
      · linarith [ha_zero, hb_vk, hu_pos]
    · linarith [ha_uk, hu_pos]
  · intro k hk
    have hu_neg := hu.2 k hk
    have hv_neg := hv.2 k hk
    have h1 : a * u k ≤ 0 := mul_nonpos_of_nonneg_of_nonpos ha (le_of_lt hu_neg)
    have h2 : b * v k ≤ 0 := mul_nonpos_of_nonneg_of_nonpos hb (le_of_lt hv_neg)
    by_contra h_not
    have h_sum_ge : 0 ≤ a * u k + b * v k := by linarith
    have ha0 : a * u k = 0 := by nlinarith
    have hb0 : b * v k = 0 := by nlinarith
    cases' mul_eq_zero.mp ha0 with ha_zero ha_uk
    · cases' mul_eq_zero.mp hb0 with hb_zero hb_vk
      · linarith [ha_zero, hb_zero, hab]
      · linarith [ha_zero, hb_vk, hv_neg]
    · linarith [ha_uk, hu_neg]

def memberSensitivity (G_k : Matrix (Fin (3 * N)) (Fin (3 * N)) ℝ) (phi : Fin (3 * N) → ℝ) : ℝ :=
  dotProduct phi (G_k.mulVec phi)

theorem sensitivity_linear (G1 G2 : Matrix (Fin (3 * N)) (Fin (3 * N)) ℝ) (phi : Fin (3 * N) → ℝ) (c : ℝ) :
    memberSensitivity (G1 + c • G2) phi = memberSensitivity G1 phi + c * memberSensitivity G2 phi := by
  dsimp [memberSensitivity]
  rw [add_mulVec, smul_mulVec, dotProduct_add, dotProduct_smul]
  rfl

theorem sensitivity_bounded_expansion 
    (G_k : Matrix (Fin (3 * N)) (Fin (3 * N)) ℝ) (phi : Fin (3 * N) → ℝ) 
    (B : ℝ) (hB : ∀ i j, abs (G_k i j) ≤ B) :
    abs (memberSensitivity G_k phi) ≤ 
      ∑ i : Fin (3 * N), ∑ j : Fin (3 * N), abs (phi i) * B * abs (phi j) := by
  dsimp [memberSensitivity, dotProduct, mulVec]
  have h_le : abs (∑ i, phi i * ∑ j, G_k i j * phi j) ≤ ∑ i, abs (phi i * ∑ j, G_k i j * phi j) := Finset.abs_sum_le_sum_abs _ _
  apply le_trans h_le
  apply Finset.sum_le_sum
  intro i _
  rw [abs_mul]
  have h_inner : abs (∑ j, G_k i j * phi j) ≤ ∑ j, abs (G_k i j * phi j) := Finset.abs_sum_le_sum_abs _ _
  have h_step1 := mul_le_mul_of_nonneg_left h_inner (abs_nonneg (phi i))
  apply le_trans h_step1
  rw [Finset.mul_sum]
  apply Finset.sum_le_sum
  intro j _
  rw [abs_mul]
  have h_g_bound := hB i j
  have h_phi_nonneg := abs_nonneg (phi j)
  have h_phi_abs_mul := mul_le_mul_of_nonneg_right h_g_bound h_phi_nonneg
  have h_final := mul_le_mul_of_nonneg_left h_phi_abs_mul (abs_nonneg (phi i))
  linarith

def tangentStiffness (Ke Kg_matrix : Matrix (Fin (3 * N)) (Fin (3 * N)) ℝ) : Matrix (Fin (3 * N)) (Fin (3 * N)) ℝ :=
  Ke + Kg_matrix

def IsPositiveDefinite (K : Matrix (Fin (3 * N)) (Fin (3 * N)) ℝ) : Prop :=
  ∀ v : Fin (3 * N) → ℝ, (∃ i, v i ≠ 0) → 0 < dotProduct v (K.mulVec v)

theorem dynamic_stability_positive_definiteness 
    (Ke Kg_matrix : Matrix (Fin (3 * N)) (Fin (3 * N)) ℝ)
    (hKe : IsPositiveDefinite Ke)
    (hKg_bound : ∀ v, 0 ≤ dotProduct v (Kg_matrix.mulVec v)) :
    IsPositiveDefinite (tangentStiffness Ke Kg_matrix) := by
  intro v hv
  dsimp [tangentStiffness]
  rw [Matrix.add_mulVec, dotProduct_add]
  have h1 := hKe v hv
  have h2 := hKg_bound v
  linarith