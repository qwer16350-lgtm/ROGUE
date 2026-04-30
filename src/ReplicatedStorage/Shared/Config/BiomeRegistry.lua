return {
	Grassland = {
		Id = "Grassland",
		AssetFolder = "Grassland",
		OpenTileTemplates = {
			"Tile_Grassland_Open_A",
			"Tile_Grassland_Open_B",
			"Tile_Grassland_Open_C",
			"Tile_Grassland_Open_D",
		},
		BottleneckTileTemplates = {
			"Tile_Grassland_Bottleneck_A",
			"Tile_Grassland_Bottleneck_B",
		},
		-- Grassland 동작 보존: ServerStorage 에 A/B/C 3종이 실존하지만 기존과
		-- 동일하게 A 단일 소스만 사용한다. 변주 확장은 별도 플랜에서 결정.
		BoundarySegmentTemplates = {
			"Boundary_Grassland_WallSegment_A",
		},
		RuntimeNames = {
			Open = "Tile_Grassland_Open_Current",
			Bottleneck = "Tile_Grassland_Bottleneck_Current",
			Boundary = "Boundary_Grassland_WallSegment_Current",
		},
	},
	Desert = {
		Id = "Desert",
		AssetFolder = "Desert",
		OpenTileTemplates = {
			"Tile_Desert_Open_A",
			"Tile_Desert_Open_B",
			"Tile_Desert_Open_C",
			"Tile_Desert_Open_D",
		},
		BottleneckTileTemplates = {
			"Tile_Desert_Bottleneck_A",
			"Tile_Desert_Bottleneck_B",
		},
		BoundarySegmentTemplates = {
			"Boundary_Desert_WallSegment_A",
			"Boundary_Desert_WallSegment_B",
			"Boundary_Desert_WallSegment_C",
		},
		RuntimeNames = {
			Open = "Tile_Desert_Open_Current",
			Bottleneck = "Tile_Desert_Bottleneck_Current",
			Boundary = "Boundary_Desert_WallSegment_Current",
		},
	},
}
