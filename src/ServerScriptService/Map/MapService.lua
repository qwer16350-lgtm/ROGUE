local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local GenerationRules = require(Config:WaitForChild("GenerationRules"))

-- 축 분리에 따른 직접 의존:
--   BiomeRegistry = 자산 풀 / 런타임 네이밍 (biome 축)
--   StageData     = 좌표 루트 / spawn·origin (stage 축)
-- BiomeService 는 더 이상 이 파일에서 참조하지 않는다.
local BiomeRegistry = require(Config:WaitForChild("BiomeRegistry"))
local StageData = require(Shared:WaitForChild("StageData"))

local MapService = {}

----------------------------------------------------------------
-- Marker / runtime clone naming
----------------------------------------------------------------

--- Any RuntimeMarkers child whose Name starts with this prefix is a placement slot.
--- Expected layout: Marker_Tile_01 .. Marker_Tile_16 on a 4x4 grid
--- (row-major; index 1 top-left, 4 top-right, 13 bottom-left, 16 bottom-right).
--- Marker naming rule is biome-agnostic and reused as-is across biomes.
local TILE_MARKER_PREFIX = "Marker_Tile_"

----------------------------------------------------------------
-- Biome templates / runtime names
----------------------------------------------------------------
-- Per-biome template name lists and runtime clone prefixes now live in
-- ReplicatedStorage.Shared.Config.BiomeRegistry under each biome entry:
--   OpenTileTemplates, BottleneckTileTemplates, BoundarySegmentTemplates,
--   RuntimeNames = { Open, Bottleneck, Boundary }.
-- GenerateMap() reads these into locals; this module no longer hardcodes
-- Grassland-specific template names.

----------------------------------------------------------------
-- Bottleneck slot selection (first-pass rule)
----------------------------------------------------------------

--- Marker index i maps to (row, col) on a 4x4 grid:
---   row = floor((i-1)/TILE_GRID_COLS) + 1
---   col = ((i-1) % TILE_GRID_COLS) + 1
local TILE_GRID_COLS = 4

--- Marker indices that are allowed to become a Bottleneck tile.
--- Default = center 2x2 of a 4x4 grid. Change this table to shift valid slots.
local BOTTLENECK_CANDIDATE_MARKER_INDICES = { 6, 7, 10, 11 }

--- How many bottleneck slots to pick per GenerateMap (only 2 is implemented here).
local BOTTLENECK_COUNT = 2

--- Minimum Manhattan distance (grid cells) between two chosen bottleneck slots.
--- With the default 2x2 candidate block, value 2 accepts only diagonal pairs
--- ({6,11}, {7,10}) so bottlenecks never sit side-by-side.
local BOTTLENECK_MIN_GRID_DISTANCE = 2

----------------------------------------------------------------
-- Visual tweaks
----------------------------------------------------------------

--- Y lift (studs) so clones don't sink into the baseplate. Applies to open + bottleneck tiles.
local OPEN_TILE_Y_OFFSET = 3.5

--- Y-axis yaw options applied per tile clone on placement.
--- 90° steps so square tile art stays aligned to the grid.
local TILE_YAW_OPTIONS_DEG = { 0, 90, 180, 270 }

--- Y-axis yaw options applied per boundary segment after its ring-tangent
--- orientation is computed. 30° steps with range ±120°.
local BOUNDARY_YAW_OPTIONS_DEG = { -120, -90, -60, -30, 0, 30, 60, 90 }

--- Grassland 전용 레거시 청소 경로.
--- 구 버전은 Structure_Grassland_Bottleneck_Current 를 Workspace.Map.Structures 아래에 두었다.
--- 현재는 Tile_Grassland_Bottleneck_* 를 Workspace.Map.Ground 로 배치하므로 오래된 인스턴스를
--- 제거해 이중 렌더를 막는다. Desert 등 다른 biome 에는 해당 없음(no-op).
local LEGACY_BOTTLENECK_RUNTIME_NAME = "Structure_Grassland_Bottleneck_Current"

----------------------------------------------------------------
-- Boundary ring (circular wall inscribed in the tile field)
----------------------------------------------------------------

--- Tile markers sit at tile centers, so the real field footprint is wider
--- than the marker bounding box by one tile on each side → +TILE_SIZE_FOR_FIELD total.
local TILE_SIZE_FOR_FIELD = 64

local BOUNDARY_SUBFOLDER = "Boundaries"
local BOUNDS_FOLDER_NAME = "Bounds"

-- Source template names and runtime name prefix are resolved per biome from
-- BiomeRegistry (BoundarySegmentTemplates / RuntimeNames.Boundary) and passed
-- into generateBoundaryRing as arguments.

local BOUNDARY_SEGMENT_COUNT = 48

--- Pull the placement ring inward by this many studs so wall thickness
--- stays inside the tile field instead of overhanging the edge.
local BOUNDARY_WALL_RADIUS_INSET = 4

----------------------------------------------------------------
-- Debug
----------------------------------------------------------------

--- Set true to print candidate dumps and per-marker role assignments to Output.
local DEBUG_OPEN_TILE_ROLL = false

--- Set true to print the computed boundary center / radius / segment count once per GenerateMap.
local DEBUG_BOUNDARY = true

--- Reset at the start of every GenerateMap; one flag per template set so the
--- candidate/Tiles-folder dump prints exactly once per set per run.
local _openDumped = false
local _bottleneckDumped = false

----------------------------------------------------------------
-- Small generic helpers
----------------------------------------------------------------

local function ensureFolder(parent, name)
	local f = parent:FindFirstChild(name)
	if f and f:IsA("Folder") then
		return f
	end
	local inst = Instance.new("Folder")
	inst.Name = name
	inst.Parent = parent
	return inst
end

--- Pick one angle (degrees) from `optionsDeg` uniformly and return it in radians.
--- Empty table → 0 rad (no-op) so callers can't divide by zero on a missing config.
local function pickYawRadians(optionsDeg: { number }): number
	if #optionsDeg == 0 then
		return 0
	end
	return math.rad(optionsDeg[math.random(1, #optionsDeg)])
end

--- Clone `source` under `parent`, name it `runtimeName`, place at `marker.Position + (0, yOffset, 0)`
--- keeping clone root rotation. `yOffset` defaults to 0. `yawRadians` (optional) adds a
--- Y-axis rotation around the placement position, applied AFTER the translation so the
--- clone spins in place, BEFORE the source's own rotation so it rotates relative to world.
local function placeSourceAtMarker(
	source: Instance,
	marker: BasePart,
	runtimeName: string,
	parent: Instance,
	yOffset: number?,
	yawRadians: number?
): boolean
	local clone = source:Clone()
	clone.Name = runtimeName
	clone.Parent = parent

	local lift = yOffset or 0
	local placePos = marker.Position + Vector3.new(0, lift, 0)
	local yaw = yawRadians or 0
	local yawCf = CFrame.Angles(0, yaw, 0)

	local ok = false
	if clone:IsA("Model") then
		local pivot = clone:GetPivot()
		local rotationOnly = pivot - pivot.Position
		local placeCf = CFrame.new(placePos) * yawCf * rotationOnly
		clone:PivotTo(placeCf)
		ok = true
	elseif clone:IsA("BasePart") then
		local cf = clone.CFrame
		local rotationOnly = cf - cf.Position
		local placeCf = CFrame.new(placePos) * yawCf * rotationOnly
		clone.CFrame = placeCf
		ok = true
	else
		warn("[MapService] Clone root must be Model or BasePart; destroying:", runtimeName)
		clone:Destroy()
	end

	return ok
end

--- Resolve marker, replace existing runtime instance, clone template, place.
--- Retained for legacy single-template callers; current map rules use the Random variant below.
local function tryPlaceFromBiome(
	contextLabel: string,
	biomeRoot: Instance,
	subfolderName: string,
	templateName: string,
	mapFolder: Instance,
	runtimeMarkers: Instance,
	markerName: string,
	outputFolderName: string,
	runtimeName: string,
	yOffset: number?
): boolean
	local sub = biomeRoot:FindFirstChild(subfolderName)
	if not sub then
		warn("[MapService]", contextLabel, "— subfolder missing:", subfolderName, "under", biomeRoot.Name)
		return false
	end

	local template = sub:FindFirstChild(templateName)
	if not template then
		warn("[MapService]", contextLabel, "— template not found:", templateName, "under", biomeRoot.Name, subfolderName)
		return false
	end

	-- recursive=true so markers grouped inside a Model (e.g. Marker_Grassland_Tile) are found.
	local marker = runtimeMarkers:FindFirstChild(markerName, true)
	if not marker or not marker:IsA("BasePart") then
		warn("[MapService]", contextLabel, "— marker missing or not BasePart:", markerName, "under Workspace.Map.RuntimeMarkers")
		return false
	end

	local outFolder = ensureFolder(mapFolder, outputFolderName)
	local existing = outFolder:FindFirstChild(runtimeName)
	if existing then
		existing:Destroy()
	end

	local placed = placeSourceAtMarker(template, marker, runtimeName, outFolder, yOffset)
	if not placed then
		warn("[MapService]", contextLabel, "— placement failed for", runtimeName)
	end
	return placed
end

--- Debug dump of a template set + the Tiles folder contents. Prints at most once per set per run.
local function debugLogCandidatesOnce(
	contextLabel: string,
	tilesFolder: Instance,
	templateNames: { string },
	setKey: string
)
	if not DEBUG_OPEN_TILE_ROLL then
		return
	end
	if setKey == "open" and _openDumped then
		return
	end
	if setKey == "bottleneck" and _bottleneckDumped then
		return
	end

	print("[MapService][debug]", contextLabel, "— tile candidate COUNT:", #templateNames)
	for i, name in ipairs(templateNames) do
		print("[MapService][debug]", contextLabel, string.format("— candidate[%d] NAME: %s", i, name))
	end

	local names = {}
	for _, c in ipairs(tilesFolder:GetChildren()) do
		table.insert(names, c.Name)
	end
	table.sort(names)
	print(
		"[MapService][debug]",
		contextLabel,
		"— Tiles folder children (" .. #names .. "):",
		table.concat(names, ", ")
	)

	for _, name in ipairs(templateNames) do
		local inst = tilesFolder:FindFirstChild(name)
		if inst then
			print("[MapService][debug]", contextLabel, "— FindFirstChild OK:", name, "| ClassName:", inst.ClassName)
		else
			print("[MapService][debug]", contextLabel, "— FindFirstChild MISSING:", name)
		end
	end

	if setKey == "open" then
		_openDumped = true
	elseif setKey == "bottleneck" then
		_bottleneckDumped = true
	end
end

--- Pick one template name from `templateNames` at random, then same placement as tryPlaceFromBiome.
local function tryPlaceFromBiomeRandomTemplate(
	contextLabel: string,
	biomeRoot: Instance,
	subfolderName: string,
	templateNames: { string },
	mapFolder: Instance,
	runtimeMarkers: Instance,
	markerName: string,
	outputFolderName: string,
	runtimeName: string,
	yOffset: number?
): boolean
	if #templateNames == 0 then
		warn("[MapService]", contextLabel, "— no tile template names configured")
		return false
	end

	local sub = biomeRoot:FindFirstChild(subfolderName)
	if not sub then
		warn("[MapService]", contextLabel, "— subfolder missing:", subfolderName, "under", biomeRoot.Name)
		return false
	end

	local pickIndex = math.random(1, #templateNames)
	local templateName = templateNames[pickIndex]

	if DEBUG_OPEN_TILE_ROLL then
		print(
			"[MapService][debug]",
			contextLabel,
			string.format(
				"— RANDOM pickIndex=%d (range 1..%d) SELECTED template name=%s",
				pickIndex,
				#templateNames,
				templateName
			)
		)
	end

	local template = sub:FindFirstChild(templateName)
	if not template then
		warn(
			"[MapService]",
			contextLabel,
			"— template not found:",
			templateName,
			"(picked index",
			pickIndex,
			"of",
			#templateNames,
			") under",
			biomeRoot.Name,
			subfolderName
		)
		-- Avoid leaving a stale runtime clone from a previous session when the picked source is missing.
		local outFolderEarly = ensureFolder(mapFolder, outputFolderName)
		local stale = outFolderEarly:FindFirstChild(runtimeName)
		if stale then
			if DEBUG_OPEN_TILE_ROLL then
				print("[MapService][debug]", contextLabel, "— removing stale runtime (missing template):", stale:GetFullName())
			end
			stale:Destroy()
		end
		return false
	end

	if DEBUG_OPEN_TILE_ROLL then
		print(
			"[MapService][debug]",
			contextLabel,
			"— about to clone SELECTED source:",
			templateName,
			"| ClassName:",
			template.ClassName,
			"— runtime clone name:",
			runtimeName
		)
	end

	-- recursive=true so markers grouped inside a Model (e.g. Marker_Grassland_Tile) are found.
	local marker = runtimeMarkers:FindFirstChild(markerName, true)
	if not marker or not marker:IsA("BasePart") then
		warn("[MapService]", contextLabel, "— marker missing or not BasePart:", markerName, "under Workspace.Map.RuntimeMarkers")
		return false
	end

	local outFolder = ensureFolder(mapFolder, outputFolderName)
	local existing = outFolder:FindFirstChild(runtimeName)
	if existing then
		if DEBUG_OPEN_TILE_ROLL then
			print("[MapService][debug]", contextLabel, "— removing existing runtime instance before place:", existing.Name)
		end
		existing:Destroy()
	end

	local yawRadians = pickYawRadians(TILE_YAW_OPTIONS_DEG)

	if DEBUG_OPEN_TILE_ROLL then
		print(
			"[MapService][debug]",
			contextLabel,
			string.format("— RANDOM tile yaw = %.0f deg", math.deg(yawRadians))
		)
	end

	local placed = placeSourceAtMarker(template, marker, runtimeName, outFolder, yOffset, yawRadians)
	if not placed then
		warn("[MapService]", contextLabel, "— placement failed for", runtimeName)
	end

	if DEBUG_OPEN_TILE_ROLL and placed then
		local placedInst = outFolder:FindFirstChild(runtimeName)
		if placedInst then
			print(
				"[MapService][debug]",
				contextLabel,
				"— placed under",
				outFolder:GetFullName(),
				"| Name:",
				placedInst.Name,
				"| Source template was:",
				templateName
			)
		end
	end

	return placed
end

--- Returns BasePart descendants of `runtimeMarkers` whose Name starts with `prefix`,
--- sorted by Name (stable order across runs). Walks descendants (not just direct children)
--- so markers grouped inside a Model (e.g. Marker_Grassland_Tile) are still found.
--- Non-BasePart matches emit a warn and are skipped.
local function collectTileMarkers(runtimeMarkers: Instance, prefix: string): { BasePart }
	local out: { BasePart } = {}
	local prefixLen = #prefix

	for _, child in ipairs(runtimeMarkers:GetDescendants()) do
		if child.Name:sub(1, prefixLen) == prefix then
			if child:IsA("BasePart") then
				table.insert(out, child)
			else
				warn(
					"[MapService] Open tile — marker name matches prefix but is not BasePart; skipping:",
					child.Name,
					"| ClassName:",
					child.ClassName
				)
			end
		end
	end

	table.sort(out, function(a, b)
		return a.Name < b.Name
	end)

	return out
end

--- Destroy any leftover runtime tiles in `outFolder` whose Name starts with `prefix`,
--- so reruns don't accumulate clones (and stale single-name clones are removed too).
local function pruneRuntimeTiles(outFolder: Instance, prefix: string)
	local prefixLen = #prefix
	for _, child in ipairs(outFolder:GetChildren()) do
		if child.Name:sub(1, prefixLen) == prefix then
			child:Destroy()
		end
	end
end

--- Biome-agnostic cleanup for stage transitions.
--- 이전 stage 의 biome prefix 가 다른 경우 `pruneRuntimeTiles(prefix=...)` 만으로는
--- 잔존 클론을 못 잡는다(예: Grassland→Desert 전환 시 Tile_Grassland_*_Current 가 남음).
--- 이를 막기 위해 Ground / Bounds / Structures 세 폴더 하위에서 이름에 "_Current"
--- 토큰을 포함한 모든 자식을 제거한다. 다른 Map 하위 폴더(RuntimeMarkers / Decor /
--- SpawnPoints 등)는 건드리지 않는다.
---
--- 호환성 전제: 모든 biome 의 RuntimeNames (Open / Bottleneck / Boundary) 는 반드시
--- "_Current" 토큰을 포함해야 한다 (BiomeRegistry 규약). 향후 다른 토큰을 쓰는 biome 을
--- 추가하려면 이 prune 정책도 같이 갱신해야 한다.
--- 또한 정적 자산(예: Ground_Base) 이름에 "_Current" 를 넣지 말아야 한다 —
--- 실수로 삭제될 수 있음.
local function pruneAllRuntimeCurrent(mapFolder: Instance)
	for _, folderName in ipairs({ "Ground", "Bounds", "Structures" }) do
		local f = mapFolder:FindFirstChild(folderName)
		if f then
			for _, child in ipairs(f:GetChildren()) do
				if child.Name:find("_Current") then
					child:Destroy()
				end
			end
		end
	end
end

----------------------------------------------------------------
-- Bottleneck picking
----------------------------------------------------------------

local function indexToCell(idx: number, cols: number): (number, number)
	local zero = idx - 1
	local row = math.floor(zero / cols) + 1
	local col = (zero % cols) + 1
	return row, col
end

local function manhattan(r1: number, c1: number, r2: number, c2: number): number
	return math.abs(r1 - r2) + math.abs(c1 - c2)
end

--- From `candidates` (allowed marker indices), pick two distinct indices whose
--- grid Manhattan distance is >= `minDist`. Falls back to any distinct pair if
--- no pair satisfies the distance rule. Returns `nil` when fewer than 2 valid
--- candidates exist.
local function pickBottleneckIndices(
	markerCount: number,
	candidates: { number },
	count: number,
	minDist: number,
	cols: number
): (number?, number?)
	if count ~= 2 then
		warn("[MapService] Bottleneck — only BOTTLENECK_COUNT == 2 is implemented; got", count)
		count = 2
	end

	local valid = {}
	for _, i in ipairs(candidates) do
		if type(i) == "number" and i >= 1 and i <= markerCount then
			table.insert(valid, i)
		else
			warn(
				"[MapService] Bottleneck — candidate index out of range, skipping:",
				i,
				"(markerCount=",
				markerCount,
				")"
			)
		end
	end

	if #valid < count then
		warn(
			"[MapService] Bottleneck — not enough valid candidate markers:",
			#valid,
			"(need",
			count,
			") — skipping bottleneck placement"
		)
		return nil, nil
	end

	local passing = {}
	local allPairs = {}
	for i = 1, #valid - 1 do
		for j = i + 1, #valid do
			local a, b = valid[i], valid[j]
			local ra, ca = indexToCell(a, cols)
			local rb, cb = indexToCell(b, cols)
			local d = manhattan(ra, ca, rb, cb)
			table.insert(allPairs, { a = a, b = b, d = d })
			if d >= minDist then
				table.insert(passing, { a = a, b = b, d = d })
			end
		end
	end

	local pool = passing
	if #pool == 0 then
		warn(
			"[MapService] Bottleneck — no candidate pair passes minGridDistance >=",
			minDist,
			"; falling back to any distinct pair"
		)
		pool = allPairs
		if #pool == 0 then
			return nil, nil
		end
	end

	local chosen = pool[math.random(1, #pool)]

	if DEBUG_OPEN_TILE_ROLL then
		print(
			"[MapService][debug] Bottleneck — valid candidates:",
			table.concat(valid, ", "),
			"| passing pairs:",
			#passing,
			"/ all pairs:",
			#allPairs,
			"| SELECTED indices:",
			chosen.a,
			"&",
			chosen.b,
			"(grid manhattan =",
			chosen.d,
			")"
		)
	end

	return chosen.a, chosen.b
end

----------------------------------------------------------------
-- Boundary ring placement
----------------------------------------------------------------

--- Compute field bounds from live marker positions. Uses bounding box center
--- (not marker average) so asymmetric / missing markers don't skew the ring
--- toward the denser side.
local function computeTileFieldBounds(markers: { BasePart })
	local minX, maxX = math.huge, -math.huge
	local minZ, maxZ = math.huge, -math.huge
	local sumY = 0

	for _, m in ipairs(markers) do
		local p = m.Position
		if p.X < minX then minX = p.X end
		if p.X > maxX then maxX = p.X end
		if p.Z < minZ then minZ = p.Z end
		if p.Z > maxZ then maxZ = p.Z end
		sumY = sumY + p.Y
	end

	local count = #markers
	local avgY = (count > 0) and (sumY / count) or 0
	local centerX = (minX + maxX) * 0.5
	local centerZ = (minZ + maxZ) * 0.5
	local width = (maxX - minX) + TILE_SIZE_FOR_FIELD
	local depth = (maxZ - minZ) + TILE_SIZE_FOR_FIELD
	local diameter = math.min(width, depth)
	local radius = diameter * 0.5
	local wallRadius = radius - BOUNDARY_WALL_RADIUS_INSET

	return {
		minX = minX, maxX = maxX, minZ = minZ, maxZ = maxZ,
		centerX = centerX, centerZ = centerZ, avgY = avgY,
		width = width, depth = depth,
		diameter = diameter, radius = radius, wallRadius = wallRadius,
	}
end

--- Resolve every boundary segment template declared by the biome into real
--- Instances under ServerStorage.MapAssets.Biomes.<Biome>.Boundaries.
--- Missing names emit a warn and are skipped; returns the (possibly empty)
--- list of found sources. Caller must handle the empty case.
local function resolveBoundarySegmentSources(
	biomeRoot: Instance,
	templateNames: { string }
): { Instance }
	local out: { Instance } = {}

	local sub = biomeRoot:FindFirstChild(BOUNDARY_SUBFOLDER)
	if not sub then
		warn("[MapService] Boundary — subfolder missing:", BOUNDARY_SUBFOLDER, "under", biomeRoot.Name)
		return out
	end

	if #templateNames == 0 then
		warn("[MapService] Boundary — no segment templates configured for biome", biomeRoot.Name)
		return out
	end

	for _, templateName in ipairs(templateNames) do
		local source = sub:FindFirstChild(templateName)
		if source then
			table.insert(out, source)
		else
			warn(
				"[MapService] Boundary — source not found:",
				templateName,
				"under",
				biomeRoot.Name,
				BOUNDARY_SUBFOLDER
			)
		end
	end

	return out
end

local function placeBoundarySegmentClone(
	source: Instance,
	runtimeName: string,
	parent: Instance,
	targetCf: CFrame
): boolean
	local clone = source:Clone()
	clone.Name = runtimeName
	clone.Parent = parent

	if clone:IsA("Model") then
		clone:PivotTo(targetCf)
		return true
	elseif clone:IsA("BasePart") then
		clone.CFrame = targetCf
		return true
	end

	warn("[MapService] Boundary — source root must be Model or BasePart; destroying:", runtimeName)
	clone:Destroy()
	return false
end

--- Build a circular ring of boundary segments inscribed in the tile field.
--- Center/radius are recomputed from live markers every call (no fixed coords,
--- no dependency on Ground_Base center). Template names and runtime name
--- prefix are provided by the caller (from BiomeRegistry).
local function generateBoundaryRing(
	mapFolder: Instance,
	biomeRoot: Instance,
	markers: { BasePart },
	templateNames: { string },
	runtimeNamePrefix: string
)
	if #markers < 2 then
		warn("[MapService] Boundary — not enough tile markers to compute bounds:", #markers)
		return
	end

	local sources = resolveBoundarySegmentSources(biomeRoot, templateNames)
	if #sources == 0 then
		return
	end

	local boundsFolder = ensureFolder(mapFolder, BOUNDS_FOLDER_NAME)
	pruneRuntimeTiles(boundsFolder, runtimeNamePrefix)

	local b = computeTileFieldBounds(markers)

	if DEBUG_BOUNDARY then
		print(string.format(
			"[MapService][boundary] biome=%s center=(%.2f, %.2f, %.2f) width=%.2f depth=%.2f diameter=%.2f radius=%.2f wallRadius=%.2f segments=%d sources=%d",
			biomeRoot.Name,
			b.centerX, b.avgY, b.centerZ,
			b.width, b.depth, b.diameter, b.radius, b.wallRadius,
			BOUNDARY_SEGMENT_COUNT, #sources
		))
	end

	local twoPi = math.pi * 2
	for i = 1, BOUNDARY_SEGMENT_COUNT do
		local theta = (i - 1) * (twoPi / BOUNDARY_SEGMENT_COUNT)
		local cosT = math.cos(theta)
		local sinT = math.sin(theta)

		local pos = Vector3.new(
			b.centerX + b.wallRadius * cosT,
			b.avgY,
			b.centerZ + b.wallRadius * sinT
		)
		-- Tangent points counter-clockwise along the ring so segment LookVector
		-- lies flush with the wall direction at that angle.
		local tangent = Vector3.new(-sinT, 0, cosT)
		local targetCf = CFrame.lookAt(pos, pos + tangent, Vector3.yAxis)

		-- Local-axis yaw spin around the segment's own pivot; pos is unchanged.
		local yawRadians = pickYawRadians(BOUNDARY_YAW_OPTIONS_DEG)
		targetCf = targetCf * CFrame.Angles(0, yawRadians, 0)

		-- Single-source biomes skip math.random so RNG sequence (and therefore
		-- subsequent yaw picks on the next iteration) stays bit-identical to
		-- the legacy single-template implementation.
		local sourceIdx = 1
		if #sources > 1 then
			sourceIdx = math.random(1, #sources)
		end
		local source = sources[sourceIdx]

		local runtimeName = string.format("%s_%02d", runtimeNamePrefix, i)
		placeBoundarySegmentClone(source, runtimeName, boundsFolder, targetCf)
	end
end

----------------------------------------------------------------
-- Entry point
----------------------------------------------------------------

--- stageIndex 생략 시 1층으로 폴백 (StageBootstrap 외부에서의 직접 호출 호환).
--- 이 함수는 stage 축(좌표)과 biome 축(자산) 을 서로 다른 문자열 키로 해석한다:
---   biomeName      → BiomeRegistry[...]  →  ServerStorage.MapAssets.Biomes.<AssetFolder>
---   markerRootName → Workspace.Map.RuntimeMarkers.<markerRootName>
function MapService.GenerateMap(stageIndex: number?)
	_openDumped = false
	_bottleneckDumped = false

	if not GenerationRules.RequireBottleneck then
		return
	end

	local idx = stageIndex or 1

	-- stage 축: 좌표 루트 / biome 축: 자산 풀. 두 축은 독립적으로 해석한다.
	local biomeName = StageData.getBiomeName(idx)
	local markerRootName = StageData.getMarkerRootName(idx)
	local biomeData = BiomeRegistry[biomeName]
	if not biomeData then
		warn(
			"[MapService] Biome registry miss; skip GenerateMap. stageIndex=",
			idx,
			"biome=",
			biomeName,
			"markerRoot=",
			markerRootName
		)
		return
	end

	-- AssetFolder 는 biome 축 전용 (ServerStorage 자산 lookup). marker 조회에는 사용하지 않는다.
	local assetFolderName = biomeData.AssetFolder

	-- Resolve biome-provided template lists and runtime clone name prefixes.
	-- These used to be module-level constants hardcoded for Grassland.
	local openTemplates = biomeData.OpenTileTemplates
	local bottleneckTemplates = biomeData.BottleneckTileTemplates
	local boundaryTemplates = biomeData.BoundarySegmentTemplates
	local runtimeNames = biomeData.RuntimeNames
	if type(openTemplates) ~= "table" or #openTemplates == 0
		or type(bottleneckTemplates) ~= "table" or #bottleneckTemplates == 0
		or type(boundaryTemplates) ~= "table" or #boundaryTemplates == 0
		or type(runtimeNames) ~= "table"
		or type(runtimeNames.Open) ~= "string" or runtimeNames.Open == ""
		or type(runtimeNames.Bottleneck) ~= "string" or runtimeNames.Bottleneck == ""
		or type(runtimeNames.Boundary) ~= "string" or runtimeNames.Boundary == ""
	then
		warn(
			"[MapService] Biome entry missing required template/runtime-name fields; skip GenerateMap. stageIndex=",
			idx,
			"biome=",
			biomeName,
			"assetFolder=",
			assetFolderName
		)
		return
	end
	local openRuntimePrefix = runtimeNames.Open
	local bottleneckRuntimePrefix = runtimeNames.Bottleneck
	local boundaryRuntimePrefix = runtimeNames.Boundary

	local mapAssets = ServerStorage:FindFirstChild("MapAssets")
	if not mapAssets then
		warn("[MapService] ServerStorage.MapAssets missing — add Rojo mapping or create folder in Studio")
		return
	end

	local biomes = mapAssets:FindFirstChild("Biomes")
	if not biomes then
		warn("[MapService] ServerStorage.MapAssets.Biomes missing")
		return
	end

	local biomeRoot = biomes:FindFirstChild(assetFolderName)
	if not biomeRoot then
		warn("[MapService] Biome folder not found:", assetFolderName)
		return
	end

	local mapFolder = ensureFolder(Workspace, "Map")

	-- Stage 전환 시 이전 biome 잔존 클론을 biome 구분 없이 전수 제거.
	-- 기존 pruneRuntimeTiles(prefix=...) 호출은 아래에서 그대로 유지 (no-op 중복, 최소 diff 목적).
	pruneAllRuntimeCurrent(mapFolder)

	local runtimeMarkersRoot = mapFolder:FindFirstChild("RuntimeMarkers")
	if not runtimeMarkersRoot then
		warn(
			"[MapService] Workspace.Map.RuntimeMarkers missing — place folder and one or more",
			TILE_MARKER_PREFIX .. "*"
		)
		return
	end

	--- Markers 는 stage 축에 소속된다 — `Workspace.Map.RuntimeMarkers.<markerRootName>` 하위의
	--- Marker_Tile_* 좌표를 읽는다. biome 과는 독립적으로 stage 마다 고유한 좌표 루트를 가진다.
	local runtimeMarkers = runtimeMarkersRoot:FindFirstChild(markerRootName)
	if not runtimeMarkers then
		warn(string.format(
			"[MapService] Workspace.Map.RuntimeMarkers.%s missing — place %s* under that stage marker root (stageIndex=%d biome=%s)",
			markerRootName, TILE_MARKER_PREFIX, idx, biomeName
		))
		return
	end

	-- Remove any stale Structure-style bottleneck clone from older builds.
	local structuresFolder = mapFolder:FindFirstChild("Structures")
	if structuresFolder then
		local legacy = structuresFolder:FindFirstChild(LEGACY_BOTTLENECK_RUNTIME_NAME)
		if legacy then
			legacy:Destroy()
		end
	end

	local groundFolder = ensureFolder(mapFolder, "Ground")
	pruneRuntimeTiles(groundFolder, openRuntimePrefix)
	pruneRuntimeTiles(groundFolder, bottleneckRuntimePrefix)

	local tileMarkers = collectTileMarkers(runtimeMarkers, TILE_MARKER_PREFIX)
	if #tileMarkers == 0 then
		warn(
			"[MapService] Open tile — no markers with prefix",
			TILE_MARKER_PREFIX,
			"under Workspace.Map.RuntimeMarkers; skipping tile placement"
		)
		return
	end

	if DEBUG_OPEN_TILE_ROLL then
		local names = {}
		for _, m in ipairs(tileMarkers) do
			table.insert(names, m.Name)
		end
		print(
			"[MapService][debug] collected",
			#tileMarkers,
			"tile marker(s):",
			table.concat(names, ", ")
		)
	end

	local tilesFolder = biomeRoot:FindFirstChild("Tiles")
	if tilesFolder then
		debugLogCandidatesOnce("Open tile", tilesFolder, openTemplates, "open")
		debugLogCandidatesOnce("Bottleneck tile", tilesFolder, bottleneckTemplates, "bottleneck")
	end

	local bottleneckSet: { [number]: boolean } = {}
	local bnA, bnB = pickBottleneckIndices(
		#tileMarkers,
		BOTTLENECK_CANDIDATE_MARKER_INDICES,
		BOTTLENECK_COUNT,
		BOTTLENECK_MIN_GRID_DISTANCE,
		TILE_GRID_COLS
	)
	if bnA and bnB then
		bottleneckSet[bnA] = true
		bottleneckSet[bnB] = true
	end

	for i, marker in ipairs(tileMarkers) do
		local isBottleneck = bottleneckSet[i] == true
		local templates = isBottleneck and bottleneckTemplates or openTemplates
		local runtimePrefix = isBottleneck and bottleneckRuntimePrefix or openRuntimePrefix
		local runtimeName = string.format("%s_%02d", runtimePrefix, i)
		local ctxLabel = (isBottleneck and "Bottleneck tile [" or "Open tile [") .. marker.Name .. "]"

		if DEBUG_OPEN_TILE_ROLL then
			print(
				"[MapService][debug] marker",
				marker.Name,
				"(i=" .. i .. ") →",
				isBottleneck and "bottleneck" or "open",
				"| runtime:",
				runtimeName
			)
		end

		tryPlaceFromBiomeRandomTemplate(
			ctxLabel,
			biomeRoot,
			"Tiles",
			templates,
			mapFolder,
			runtimeMarkers,
			marker.Name,
			"Ground",
			runtimeName,
			OPEN_TILE_Y_OFFSET
		)
	end

	generateBoundaryRing(mapFolder, biomeRoot, tileMarkers, boundaryTemplates, boundaryRuntimePrefix)
end

return MapService
