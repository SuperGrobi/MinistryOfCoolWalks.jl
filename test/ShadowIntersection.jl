@testitem "combine_lines" begin
    # TODO: Add tests for combine_lines
    @test_skip "Add tests for combine_lines"
end

@testitem "combine_along_tree" begin
    # TODO: Add tests for combine_along_tree
    @test_skip "Add tests for combine_along_tree"
end

@testitem "rebuild_lines" begin
    # TODO: Add tests for rebuild_lines
    @test_skip "Add tests for rebuild_lines"
end

@testitem "add_shadow_intervals!" begin
    cd(@__DIR__)
    using CompositeBuildings, Graphs, MetaGraphs, ShadowGraphs, ArchGDAL

    g = shadow_graph_from_file("./data/test_clifton_bike.json"; network_type=:bike)
    b = load_british_shapefiles("./data/clifton/clifton_test.shp")
    s = CompositeBuildings.cast_shadows(b, [1.0, -0.4, 0.2])

    edge_list = filter_edges(g, :sg_helper, false) |> collect
    for i in [1478, 138, 2935, 2196, 456]
        @test !has_prop(g, edge_list[i], :sg_shadow_length)
        @test !has_prop(g, edge_list[i], :sg_shadow_geometry)
    end

    add_shadow_intervals!(g, s)
    edge_ids = [2774, 1192, 1743, 1608, 2612, 1076, 261, 2565, 338, 2766]
    sl_before = []
    for i in edge_ids
        @test has_prop(g, edge_list[i], :sg_shadow_length)
        push!(sl_before, get_prop(g, edge_list[i], :sg_shadow_length))
        if has_prop(g, edge_list[i], :sg_shadow_geometry)
            @test get_prop(g, edge_list[i], :sg_shadow_length) > 0.0
            @test ArchGDAL.distance(get_prop(g, edge_list[i], :sg_shadow_geometry), get_prop(g, edge_list[i], :sg_street_geometry)) ≈ 0.0 atol = 1e-8
        else
            @test get_prop(g, edge_list[i], :sg_shadow_length) == 0.0
        end
    end

    # test repeatability
    add_shadow_intervals!(g, first(s, 100))
    for (i, sl) in zip(edge_ids, sl_before)
        @test get_prop(g, edge_list[i], :sg_shadow_length) ≈ sl atol = 1e-8
    end

    # test resetting
    affected_scr = [59, 69, 206, 639, 795, 826, 931, 1028, 1028, 1050, 1111, 1138, 1157, 1235, 1305, 1305, 1345, 1599, 1599, 1599]
    affected_dst = [1111, 931, 826, 1157, 1599, 206, 69, 1050, 1305, 1028, 59, 1599, 639, 1345, 1028, 1599, 1235, 795, 1138, 1305]
    affected_edges = map((s, d) -> Edge(s, d), affected_scr, affected_dst)

    non_affected_edges = filter(e -> !(e in affected_edges), edge_list)
    affected_sl_before = map(e -> get_prop(g, e, :sg_shadow_length), affected_edges)

    # check that there are more edges with shadows
    @test length(filter_edges(g, :sg_shadow_geometry) |> collect) > 20

    # do the resetting
    add_shadow_intervals!(g, first(s, 10); clear_old_shadows=true)

    # check that non affected are reset
    @test mapreduce(e -> get_prop(g, e, :sg_shadow_length) ≈ 0.0, &, non_affected_edges)
    @test length(filter_edges(g, :sg_shadow_geometry) |> collect) == 20

    # check that affected are between zero and value before
    for (edge, sl) in zip(affected_edges, affected_sl_before)
        sl_after = get_prop(g, edge, :sg_shadow_length)
        @test 0.0 < sl_after
        @test sl_after ≈ sl || sl_after <= sl  # might be slightly larger, due to numerics.
    end
end

@testitem "check_shadow_angle_integrity" begin
    using ShadowGraphs, CompositeBuildings, DataFrames
    cd(@__DIR__)
    g = shadow_graph_from_file("./data/test_clifton_bike.json"; network_type=:bike)
    b = load_british_shapefiles("./data/clifton/clifton_test.shp")
    s = CompositeBuildings.cast_shadows(b, [1.0, -0.4, 0.2])
    add_shadow_intervals!(g, s)

    no_problem_bool, no_problems = check_shadow_angle_integrity(g, 0.9π)
    @test nrow(no_problems) == 1506
    @test no_problem_bool

    no_problem_bool, problems = check_shadow_angle_integrity(g, 0.1π)
    @test nrow(problems) == 203
    @test !no_problem_bool
end