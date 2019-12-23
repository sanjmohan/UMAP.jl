
@testset "umap tests" begin

    @testset "constructor" begin
        @testset "argument validation tests" begin
            data = rand(5, 10)
            @test_throws ArgumentError UMAP_([1. 1.]; n_neighbors=0) # n_neighbors error
            @test_throws ArgumentError UMAP_([1. 1.], 0; n_neighbors=1) # n_comps error
            @test_throws ArgumentError UMAP_([1. 1.], 2; n_neighbors=1) # n_comps error
            @test_throws ArgumentError UMAP_([1. 1.; 1. 1.; 1. 1.];
                    n_neighbors=1, min_dist = 0.) # min_dist error
        end
    end

    @testset "input type stability tests" begin
        data = rand(5, 100)
        umap_ = UMAP_(data; init=:random)
        @test umap_ isa UMAP_{Float64}
        @test size(umap_.graph) == (100, 100)
        @test size(umap_.embedding) == (2, 100)

        data = rand(Float32, 5, 100)
        @test UMAP_(data; init=:random) isa UMAP_{Float32}
    end

    @testset "fuzzy_simpl_set" begin
        data = rand(20, 500)
        k = 5
        umap_graph = fuzzy_simplicial_set(data, k, Euclidean(), 1, 1.)
        @test issymmetric(umap_graph)
        @test all(0. .<= umap_graph .<= 1.)
        data = rand(Float32, 20, 500)
        umap_graph = fuzzy_simplicial_set(data, k, Euclidean(), 1, 1.f0)
        @test issymmetric(umap_graph)
        @test eltype(umap_graph) == Float32

        data = 2 .* rand(20, 1000) .- 1
        umap_graph = fuzzy_simplicial_set(data, k, CosineDist(), 1, 1.)
        @test issymmetric(umap_graph)
        @test all(0. .<= umap_graph .<= 1.)
    end

    @testset "smooth_knn_dists" begin
        dists = [0., 1., 2., 3., 4., 5.]
        rho = 1
        k = 6
        local_connectivity = 1
        bandwidth = 1.
        niter = 64
        sigma = smooth_knn_dist(dists, rho, k, bandwidth, niter)
        psum(ds, r, s) = sum(exp.(-max.(ds .- r, 0.) ./ s))
        @test psum(dists, rho, sigma) - log2(k)*bandwidth < SMOOTH_K_TOLERANCE

        knn_dists = [0. 0. 0.;
                     1. 2. 3.;
                     2. 4. 5.;
                     3. 4. 5.;
                     4. 6. 6.;
                     5. 6. 10.]
        rhos, sigmas = smooth_knn_dists(knn_dists, k, local_connectivity)
        @test rhos == [1., 2., 3.]
        diffs = [psum(knn_dists[:,i], rhos[i], sigmas[i]) for i in 1:3] .- log2(6)
        @test all(diffs .< SMOOTH_K_TOLERANCE)

        knn_dists = [0. 0. 0.;
                     0. 1. 2.;
                     0. 2. 3.]
        rhos, sigmas = smooth_knn_dists(knn_dists, 2, 1)
        @test rhos == [0., 1., 2.]

        rhos, sigmas = smooth_knn_dists(knn_dists, 2, 1.5)
        @test rhos == [0., 1.5, 2.5]
    end

    @testset "compute_membership_strengths" begin
        knns = [1 2 3; 2 1 2]
        dists = [0. 0. 0.; 2. 2. 3.]
        rhos = [2., 1., 4.]
        sigmas = [1., 1., 1.]
        true_rows = [1, 2, 2, 1, 3, 2]
        true_cols = [1, 1, 2, 2, 3, 3]
        true_vals = [0., 1., 0., exp(-1.), 0., 1.]
        rows, cols, vals = compute_membership_strengths(knns, dists, rhos, sigmas)
        @test rows == true_rows
        @test cols == true_cols
        @test vals == true_vals
    end

    @testset "optimize_embedding" begin
        A = sprand(10000, 10000, 0.001)
        B = dropzeros(A + A' - A .* A')
        layout = spectral_layout(B, 5)
        n_epochs = 1
        initial_alpha = 1.
        gamma = 1.
        neg_sample_rate = 5
        a = 1.
        b = 2.
        embedding = optimize_embedding!(layout, B, n_epochs, initial_alpha, gamma, neg_sample_rate, a, b)
        @test embedding isa Array{Float64, 2}
    end

    @testset "spectral_layout" begin
        A = sprand(10000, 10000, 0.001)
        B = dropzeros(A + A' - A .* A')
        layout = spectral_layout(B, 5)
        @test layout isa Array{Float64, 2}
        @inferred spectral_layout(B, 5)
        layout32 = spectral_layout(convert(SparseMatrixCSC{Float32}, B), 5)
        @test layout32 isa Array{Float32, 2}
    end

end
