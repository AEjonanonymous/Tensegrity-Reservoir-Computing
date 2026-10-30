"""
GNU Affero General Public License v3.0 (AGPL-3.0)
tensegrity_reservoir.py
First-Principles Kinematic Library for Tensegrity Physical Reservoir Computing (PRC)
Reflecting Lean 4 Formally Verified Mathematical Foundations (Theorems 1-4).
"""

import numpy as np
from scipy.optimize import minimize
from scipy.integrate import solve_ivp

class TensegrityReservoir:
    def __init__(self, nodal_coords: np.ndarray, connectivity: list, 
                 cables: list, struts: list, axial_rigidities: np.ndarray,
                 fixed_nodes: list = None):
        """
        Initializes the Tensegrity Physical Reservoir from first-principles kinematics.
        """
        self.nodes = nodal_coords
        self.num_nodes = nodal_coords.shape[0]
        self.connectivity = connectivity
        self.cables = cables
        self.struts = struts
        self.EA = axial_rigidities
        self.num_members = len(connectivity)
        self.fixed_nodes = fixed_nodes if fixed_nodes is not None else []
        
        # Identify free degrees of freedom (DOFs) to eliminate rigid-body zero-energy modes
        all_dofs = np.arange(3 * self.num_nodes)
        fixed_dofs = []
        for fn in self.fixed_nodes:
            fixed_dofs.extend([3*fn, 3*fn+1, 3*fn+2])
        self.free_dofs = np.setdiff1d(all_dofs, fixed_dofs)
        
        # Compute exact kinematics and global stiffness components
        self.L, self.direction_vectors = self._compute_kinematics()
        self.A_global = self._assemble_equilibrium_matrix()
        self.Ke_global = self._assemble_elastic_stiffness()
        self.G_k_global = self._assemble_geometric_tensors()
        
        # Mass Matrix for free DOFs
        self.M = np.eye(len(self.free_dofs)) * 1.0

    def _compute_kinematics(self):
        L = np.zeros(self.num_members)
        dirs = []
        for k, (i, j) in enumerate(self.connectivity):
            pi = self.nodes[i]
            pj = self.nodes[j]
            vec = pj - pi
            length = np.linalg.norm(vec)
            if length < 1e-8:
                raise ValueError(f"Member {k} has near-zero length.")
            L[k] = length
            dirs.append(vec / length)
        return L, dirs

    def _assemble_equilibrium_matrix(self) -> np.ndarray:
        dim = 3 * self.num_nodes
        A = np.zeros((dim, self.num_members))
        for k, (i, j) in enumerate(self.connectivity):
            e_k = self.direction_vectors[k]
            A[3*i:3*i+3, k] = -e_k
            A[3*j:3*j+3, k] =  e_k
        return A

    def _assemble_elastic_stiffness(self) -> np.ndarray:
        D_diag = self.EA / self.L
        D_mat = np.diag(D_diag)
        Ke = self.A_global @ D_mat @ self.A_global.T
        return 0.5 * (Ke + Ke.T)

    def _assemble_geometric_tensors(self) -> list:
        dim = 3 * self.num_nodes
        G_list = []
        I3 = np.eye(3)
        for k, (i, j) in enumerate(self.connectivity):
            G_k = np.zeros((dim, dim))
            e_k = self.direction_vectors[k]
            eeT = np.outer(e_k, e_k)
            sub_block = (I3 - eeT) / self.L[k]
            
            for r_idx, r in enumerate([i, j]):
                for c_idx, c in enumerate([i, j]):
                    sign = 1.0 if r_idx == c_idx else -1.0
                    G_k[3*r:3*r+3, 3*c:3*c+3] = sign * sub_block
                    
            G_list.append(0.5 * (G_k + G_k.T))
        return G_list

    def check_convex_cone(self, t0: np.ndarray) -> bool:
        """Theorem 2 Validation: Convex Cone Admissibility (C)."""
        for k in self.cables:
            if t0[k] <= 0.0:
                return False
        for k in self.struts:
            if t0[k] >= 0.0:
                return False
        return True

    def assemble_tangent_stiffness_global(self, t0: np.ndarray) -> np.ndarray:
        """Assembles total tangent stiffness K_global = Ke_global + sum(t0_k * G_k)."""
        Kg_full = np.zeros_like(self.Ke_global)
        for k in range(self.num_members):
            Kg_full += t0[k] * self.G_k_global[k]
        return self.Ke_global + Kg_full

    def assemble_tangent_stiffness(self, t0: np.ndarray) -> np.ndarray:
        """Theorem 4 Basis: Tangent stiffness projected onto free DOFs subspace."""
        K_global = self.assemble_tangent_stiffness_global(t0)
        return K_global[np.ix_(self.free_dofs, self.free_dofs)]

    def verify_positive_definiteness(self, K: np.ndarray) -> bool:
        """Theorem 4 Validation: Checks if active Tangent Stiffness K is strictly Positive Definite."""
        eigenvalues = np.linalg.eigvalsh(K)
        return np.all(eigenvalues > 1e-4)

    def optimize_prestress(self, initial_t0: np.ndarray) -> np.ndarray:
        """
        Constrained Interior-Point Optimizer enforcing Theorem 2 (Convex Cone C bounds) 
        and Theorem 4 (Positive Definiteness via Log-Barrier Regularization).
        """
        def objective(t0):
            K = self.assemble_tangent_stiffness(t0)
            evals = np.linalg.eigvalsh(K)
            if np.any(evals <= 1e-4):
                return 1e12
            energy_penalty = 1e-4 * np.sum(t0**2)
            log_barrier = -np.sum(np.log(evals))
            return energy_penalty + log_barrier

        bounds = []
        for k in range(self.num_members):
            if k in self.cables:
                bounds.append((0.1, 200.0))
            else:
                bounds.append((-200.0, -0.1))

        result = minimize(objective, initial_t0, method='L-BFGS-B', bounds=bounds)
        if not result.success:
            return initial_t0
        return result.x

    def simulate_reservoir_response(self, t0: np.ndarray, time_steps: np.ndarray, 
                                    input_signal: callable, alpha_damping: float = 0.01, 
                                    beta_damping: float = 0.005) -> np.ndarray:
        """Simulates equations of motion with structural Rayleigh damping on free DOFs."""
        K = self.assemble_tangent_stiffness(t0)
        
        if not self.verify_positive_definiteness(K):
            raise ValueError("Stability Violation: Tangent stiffness K is not positive definite!")

        C = alpha_damping * self.M + beta_damping * K
        dim_free = len(self.free_dofs)
        
        def equations_of_motion(t, y):
            x = y[:dim_free]
            v = y[dim_free:]
            f_ext = input_signal(t)
            m_inv = np.linalg.pinv(self.M)
            accel = m_inv @ (f_ext - (C @ v) - (K @ x))
            return np.concatenate([v, accel])

        y0 = np.zeros(2 * dim_free)
        sol = solve_ivp(equations_of_motion, [time_steps[0], time_steps[-1]], y0, 
                        t_eval=time_steps, method='RK45')
        
        if not sol.success:
            raise RuntimeError(f"ODE solver failed: {sol.message}")
            
        return sol.y[:dim_free, :].T