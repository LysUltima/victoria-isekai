Includes = {
	"sharedconstants.fxh"
	"dynamic_masks.fxh"
}

Code
[[
	static const float SEASONS_TWO_PI = 6.28318530718;

	// Snow look and snow line tuning. Edit here; reloads with the shader.
	static const float SEASONS_SNOW_MELT_FADE_END		= 0.25;	// Winter amount under which the remaining snow also fades out
	static const float SEASONS_MAP_ASPECT				= 0.44141;	// World Z/X extent (3616/8192), keeps noise cells square
	static const float SEASONS_PATCH_NOISE_GRADIENT		= 4.0;	// Typical fBm gradient per noise cell (empirical); converts patch noise units to latitude for the softness band
	static const float SEASONS_NOISE_BAKE_WIDTH			= 4096.0;	// Texels across the baked noise textures; mirrors NoiseTextureWidth in CSeasonNoiseBaker
	static const float SEASONS_SNOW_HEIGHT_MIN			= 3.0;	// Ground height where the mountain lead starts ramping in
	static const float SEASONS_SNOW_HEIGHT_MAX			= 11.0;	// Ground height where the mountain lead is at full strength
	static const float SEASONS_SNOW_ROUGHNESS			= 0.9;	// Code snow material: matte surface
	static const float SEASONS_SNOW_SPECULAR			= 0.1;	// Code snow material: dull highlight
	static const float SEASONS_DEVASTATION_MELT			= 3.0;	// The season is fully burnt off at devastation 1 / this; 3 ends the snow where the scorched ground blend saturates (Area_Max 0.33 in devastation.settings)

	// Fall / spring look tuning.
	static const float3 SEASONS_FALL_COLOR				= float3( 0.62, 0.36, 0.12 );	// Autumn overlay
	static const float3 SEASONS_SPRING_COLOR			= float3( 0.55, 0.78, 0.40 );	// Fresh spring overlay
	static const float SEASONS_FALL_LEAF_THINNING		= 0.6;	// Canopy alpha lost by a fully turned tree
	static const float SEASONS_SPRING_TREE_TINT			= 0.4;
	static const float SEASONS_TERRAIN_FALL_TINT		= 0.35;
	static const float3 SEASONS_WINTER_TREE_COLOR		= float3( 0.45, 0.47, 0.43 );	// Faded grey-green a turned canopy settles into, barely off neutral
	static const float SEASONS_WINTER_TREE_BRIGHTNESS	= 0.78;	// Winter canopies sit well below their summer brightness
	static const float SEASONS_TREE_TURN_FIRST_START	= 0.082;	// Turn dates are year fractions since 1 July; the earliest tree starts on 1 August
	static const float SEASONS_TREE_TURN_LAST_START		= 0.167;	// The latest waits until 1 September
	static const float SEASONS_TREE_TURN_LENGTH			= 0.115;	// Six weeks from green to fully turned
	static const float SEASONS_TREE_HEIGHT_LEAD			= 0.041;	// Ground at the snow-height ceiling starts a fortnight early, so mountains turn first
	static const float SEASONS_TREE_WINTER_START		= 0.416;	// Full autumn holds until 1 December
	static const float SEASONS_TREE_WINTER_LENGTH		= 0.058;	// Then drains into the winter colour over three weeks
	static const float SEASONS_TREE_WINTER_END			= 0.626;	// The winter colour holds until mid February
	static const float SEASONS_TREE_WINTER_FADE			= 0.122;	// Then gives way to the spring tint by 1 April
	static const float SEASONS_FALL_RISE_END			= 0.250;	// Ground litter reaches full on 1 October
	static const float SEASONS_FALL_HOLD_END			= 0.416;	// Holds there until 1 December
	static const float SEASONS_FALL_DECAY_LENGTH		= 0.120;	// Then eases away over six weeks
	static const float SEASONS_SPRING_RISE_END			= 0.250;	// Fresh growth reaches full on 1 April
	static const float SEASONS_SPRING_HOLD_END			= 0.416;	// Holds there until 1 June
	static const float SEASONS_SPRING_DECAY_LENGTH		= 0.200;	// Then eases into summer over ten weeks
	static const float SEASONS_TERRAIN_SPRING_TINT		= 0.25;
	static const float SEASONS_EQUATOR					= 0.0;
	static const float SEASONS_TEMPERATE_NEAR			= 0.06;
	static const float SEASONS_TEMPERATE_FAR			= 0.16;

	//////////////////////////////////////////////////
	//////// Reusable season primitives ////////////////
	//////////////////////////////////////////////////
	float SeasonGetWinterAmount( float Phase )
	{
		float MeltShare = clamp( _SeasonMeltShare, 0.05, 0.95 );
		float Warped = Phase < MeltShare ? Phase / MeltShare * 0.5 : 0.5 + ( Phase - MeltShare ) / ( 1.0 - MeltShare ) * 0.5;
		return 0.5 + 0.5 * cos( Warped * SEASONS_TWO_PI );
	}
	float SeasonGetSummerAmount( float Phase ) { return 1.0 - SeasonGetWinterAmount( Phase ); }
	// Spring rises to 1 April, holds full through May, then gives way to summer. Its triangle collapsed the flower patches within days of the
	// peak exactly as autumn's did, and it needs no year cycle because spring never crosses New Year.
	float SeasonGetSpringAmount( float Phase )
	{
		if ( Phase < SEASONS_SPRING_RISE_END )
		{
			return saturate( Phase / max( SEASONS_SPRING_RISE_END, 0.0001 ) );
		}
		return 1.0 - smoothstep( SEASONS_SPRING_HOLD_END, SEASONS_SPRING_HOLD_END + SEASONS_SPRING_DECAY_LENGTH, Phase );
	}
	// The whole year as one monotonic run from 1 July, so a foliage colour can hold across New Year instead of unwinding at it.
	float SeasonGetFallCycle( float Phase ) { return frac( Phase - 0.5 ); }
	// Autumn on the ground rises to 1 October, holds full through November, then drains away; a symmetric triangle put the litter past its
	// visible threshold within days of the peak, because it only shows where the patch mask falls under the season amount.
	float SeasonGetFallAmount( float Phase )
	{
		float Cycle = SeasonGetFallCycle( Phase );
		if ( Cycle < SEASONS_FALL_RISE_END )
		{
			return saturate( Cycle / max( SEASONS_FALL_RISE_END, 0.0001 ) );
		}
		return 1.0 - smoothstep( SEASONS_FALL_HOLD_END, SEASONS_FALL_HOLD_END + SEASONS_FALL_DECAY_LENGTH, Cycle );
	}

	float SeasonLuminance( float3 Color ) { return dot( Color, float3( 0.299, 0.587, 0.114 ) ); }
	float SeasonBlendHemispheres( float NorthSouth01, float SouthValue, float NorthValue )
	{
		// The map runs from the equator to the north; even its southern edge uses northern seasons.
		return NorthValue;
	}
	float SeasonFallAt( float NorthSouth01 ) { return SeasonBlendHemispheres( NorthSouth01, SeasonGetFallAmount( frac( _SeasonPhase + 0.5 ) ), SeasonGetFallAmount( _SeasonPhase ) ); }
	float SeasonFallCycleAt( float NorthSouth01 ) { return SeasonBlendHemispheres( NorthSouth01, SeasonGetFallCycle( frac( _SeasonPhase + 0.5 ) ), SeasonGetFallCycle( _SeasonPhase ) ); }
	float SeasonSpringAt( float NorthSouth01 ) { return SeasonBlendHemispheres( NorthSouth01, SeasonGetSpringAmount( frac( _SeasonPhase + 0.5 ) ), SeasonGetSpringAmount( _SeasonPhase ) ); }
	float SeasonMaterialAllowed( float MaterialIndex )
	{
		int Index = int( MaterialIndex + 0.5 );
		float Word = Index < 32 ? ( Index < 16 ? _SeasonMaterialFilter0 : _SeasonMaterialFilter1 ) : ( Index < 48 ? _SeasonMaterialFilter2 : _SeasonMaterialFilter3 );
		return float( ( uint( max( Word, 0.0 ) ) >> uint( Index & 15 ) ) & 1u );
	}

	// The share of the pixel that takes the season colours, weighted the way the terrain blends its materials, so the colours end where their material ends.
	float SeasonMaterialFilter( float4 DetailIndices, float4 BlendFactors )
	{
		float4 Allowed = float4( SeasonMaterialAllowed( DetailIndices.x ), SeasonMaterialAllowed( DetailIndices.y ), SeasonMaterialAllowed( DetailIndices.z ), SeasonMaterialAllowed( DetailIndices.w ) );
		return dot( BlendFactors, Allowed );
	}

	float SeasonTemperateMask( float NorthSouth01 ) { return smoothstep( SEASONS_TEMPERATE_NEAR, SEASONS_TEMPERATE_FAR, abs( NorthSouth01 - SEASONS_EQUATOR ) ); }
]]

PixelShader =
{
	# 0.5 grey = no change, white pushes the snow line toward the equator, black carves warm
	# pockets. Ref-bound - name-resolved bindings reach every mesh effect permutation.
	TextureSampler SnowCarveMaskTexture
	{
		Ref = SnowCarveMask
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Wrap"
		SampleModeV = "Clamp"
	}

	# The noise fields that depend only on map position and knobs, baked by the season panel (CSeasonNoiseBaker) and shipped as files; the signed noises sit around 0.5.
	# Red ice line wobble, green ice lane wobble, blue snow patch mask on the ice, alpha snow line noise.
	TextureSampler SeasonNoiseTexture
	{
		Ref = SeasonNoise
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Wrap"
		SampleModeV = "Clamp"
	}

	# Red frost line noise, green terrain snow patch mask, blue autumn patch mask, alpha spring patch mask.
	TextureSampler SeasonTerrainNoiseTexture
	{
		Ref = SeasonTerrainNoise
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Wrap"
		SampleModeV = "Clamp"
	}

	# The four deep-winter lines over longitude, rebuilt by CGraphicalMap whenever a control point moves: red snow north, green snow south, blue ice north, alpha ice south.
	TextureSampler SeasonCurveTexture
	{
		Ref = SeasonCurves
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Wrap"
		SampleModeV = "Clamp"
	}

	# One row: RGB is the autumn canopy colour over a tree's turn, alpha how much of it is blended in. Bound by CGraphicalMap; reloads on save.
	TextureSampler SeasonTreeAutumnRampTexture
	{
		Ref = SeasonTreeAutumnRamp
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Clamp"
		SampleModeV = "Clamp"
	}

	TextureSampler SeasonPlacementMaskTexture
	{
		Ref = SeasonPlacementMask
		MagFilter = "Linear"
		MinFilter = "Linear"
		MipFilter = "Linear"
		SampleModeU = "Wrap"
		SampleModeV = "Clamp"
	}

	Code
	[[
		// Integer bit-mix hash: exact at any cell coordinate and identical across GPUs.
		uint SeasonHashUint( float2 I )
		{
			uint2 Cell = uint2( int2( floor( I ) ) );
			uint Hash = Cell.x * 1664525u + Cell.y * 1013904223u;
			Hash = ( Hash ^ ( Hash >> 16 ) ) * 2246822519u;
			return Hash ^ ( Hash >> 13 );
		}

		static const float2 SEASON_GRADIENT_DIRECTIONS[ 16 ] = {
			float2( 1.0, 0.0 ),		 float2( 0.92388, 0.38268 ),   float2( 0.70711, 0.70711 ),   float2( 0.38268, 0.92388 ),
			float2( 0.0, 1.0 ),		 float2( -0.38268, 0.92388 ),  float2( -0.70711, 0.70711 ),  float2( -0.92388, 0.38268 ),
			float2( -1.0, 0.0 ),	 float2( -0.92388, -0.38268 ), float2( -0.70711, -0.70711 ), float2( -0.38268, -0.92388 ),
			float2( 0.0, -1.0 ),	 float2( 0.38268, -0.92388 ),  float2( 0.70711, -0.70711 ),  float2( 0.92388, -0.38268 ) };

		float2 SeasonHashGradient( float2 I )
		{
			return SEASON_GRADIENT_DIRECTIONS[ SeasonHashUint( I ) & 15u ];
		}

		// Whole cell counts, so the noise tiles across the longitude wrap.
		float SeasonNoiseTiles( float Scale ) { return max( 1.0, floor( Scale + 0.5 ) ); }
		float2 SeasonNoiseBaseUV( float2 MapCoords ) { return float2( frac( MapCoords.x ), MapCoords.y * SEASONS_MAP_ASPECT ); }

		// Anti-aliasing, not zoom shaping: an octave under about a pixel and a half per cell cannot resolve, only shimmer; it must reach a hard zero or a speckle residue remains.
		float SeasonOctaveResolve( float Tiles, float FootprintUV )
		{
			return saturate( ( 1.0 / ( Tiles * SEASONS_MAP_ASPECT * FootprintUV ) - 1.5 ) / 2.5 );
		}

		float SeasonRemapWindow( float Value, float WindowMin, float WindowMax )
		{
			return RemapClamped( Value, WindowMin, max( WindowMax, WindowMin + 0.0001 ), 0.0, 1.0 );
		}

		// Gradient noise in roughly [-1;1], quintic fade; tiles every PeriodX cells along X.
		float SeasonGradientNoise( float2 P, float PeriodX )
		{
			float2 I = floor( P );
			float2 F = frac( P );
			float2 U = F * F * F * ( F * ( F * 6.0 - 15.0 ) + 10.0 );
			float X0 = I.x - PeriodX * floor( I.x / PeriodX );
			float X1 = X0 + 1.0;
			X1 = X1 - PeriodX * floor( X1 / PeriodX );
			float A = dot( SeasonHashGradient( float2( X0, I.y ) ), F );
			float B = dot( SeasonHashGradient( float2( X1, I.y ) ), F - float2( 1.0, 0.0 ) );
			float C = dot( SeasonHashGradient( float2( X0, I.y + 1.0 ) ), F - float2( 0.0, 1.0 ) );
			float D = dot( SeasonHashGradient( float2( X1, I.y + 1.0 ) ), F - float2( 1.0, 1.0 ) );
			return lerp( lerp( A, B, U.x ), lerp( C, D, U.x ), U.y ) * 1.4142;
		}

		// An fBm octave the baked textures can carry: full at four texels per cell, gone at two, which is what a bilinear read rebuilds faithfully.
		float SeasonBakeOctaveResolve( float Tiles )
		{
			return saturate( ( SEASONS_NOISE_BAKE_WIDTH / Tiles - 2.0 ) / 2.0 );
		}

		// Octaves the bake cannot carry fade out here, so the bake does not alias and the live view holds exactly the detail the bake does.
		float SeasonFractalNoise( float2 P, float PeriodX, float OctaveCount, float Gain )
		{
			float Sum = 0.0;
			float Normalization = 0.0;
			float Amplitude = 1.0;
			int Count = (int)clamp( OctaveCount, 1.0, 6.0 );
			for ( int i = 0; i < Count; ++i )
			{
				float Resolve = SeasonBakeOctaveResolve( PeriodX );
				Sum += SeasonGradientNoise( P, PeriodX ) * Amplitude * Resolve;
				Normalization += Amplitude * Resolve;
				Amplitude *= Gain;
				if ( Amplitude <= 0.0001 || Resolve <= 0.0 )
				{
					break;
				}
				P *= 2.0;
				PeriodX *= 2.0;
			}
			return Sum / max( Normalization, 0.0001 );
		}

		float SeasonSmoothMin( float A, float B, float K, float InvK )
		{
			float H = saturate( 0.5 + 0.5 * ( B - A ) * InvK );
			return lerp( B, A, H ) - K * H * ( 1.0 - H );
		}

		// The cell's jittered point from one hash: the two coordinates take different halves of the same mix.
		float2 SeasonCellPoint( float2 Cell )
		{
			uint Hash = SeasonHashUint( Cell );
			return float2( float( Hash & 0xFFFFu ), float( Hash >> 16 ) ) / 65536.0;
		}

		// Distance to the nearest voronoi border (two-pass, Quilez style), X-periodic for the map wrap. The second pass walks the 3x3 around the
		// nearest point's own cell rather than the 5x5 around the pixel's: with one point per cell that reaches every border the nearest cell can
		// have bar rare far neighbours, at a third of the cost.
		float SeasonCellularBorderDistance( float2 P, float PeriodX, float Rounding )
		{
			float2 I = floor( P );
			float2 F = P - I;

			float2 NearestOffset = float2( 0.0, 0.0 );
			float2 NearestPoint = float2( 0.0, 0.0 );
			float NearestDistanceSquared = 8.0;
			for ( int Y1 = -1; Y1 <= 1; ++Y1 )
			{
				for ( int X1 = -1; X1 <= 1; ++X1 )
				{
					float2 Offset = float2( X1, Y1 );
					float2 Cell = I + Offset;
					Cell.x = Cell.x - PeriodX * floor( Cell.x / PeriodX );
					float2 Point = Offset + SeasonCellPoint( Cell ) - F;
					float DistanceSquared = dot( Point, Point );
					if ( DistanceSquared < NearestDistanceSquared )
					{
						NearestDistanceSquared = DistanceSquared;
						NearestPoint = Point;
						NearestOffset = Offset;
					}
				}
			}

			float BorderDistance = 8.0;
			float ClampedRounding = max( Rounding, 0.005 );
			float InvRounding = 1.0 / ClampedRounding;
			for ( int Y2 = -1; Y2 <= 1; ++Y2 )
			{
				for ( int X2 = -1; X2 <= 1; ++X2 )
				{
					float2 Offset = NearestOffset + float2( X2, Y2 );
					float2 Cell = I + Offset;
					Cell.x = Cell.x - PeriodX * floor( Cell.x / PeriodX );
					float2 Point = Offset + SeasonCellPoint( Cell ) - F;
					float2 ToPoint = Point - NearestPoint;
					if ( dot( ToPoint, ToPoint ) > 0.0001 )
					{
						BorderDistance = SeasonSmoothMin( BorderDistance, dot( 0.5 * ( NearestPoint + Point ), normalize( ToPoint ) ), ClampedRounding, InvRounding );
					}
				}
			}
			return BorderDistance;
		}

		// Snow and frost add their wobble in coverage after the ramp; the sea ice displaces _Latitude instead, so its wobble survives the plate noise layered on top.
		struct SSeasonColdField
		{
			float _Latitude;
			float _LineNorth;
			float _LineSouth;
			float _FadeNorth;
			float _FadeSouth;
			float _Noise;
		};

		// The retract, painted carve and melt fades on whichever deep-winter lines the caller fetched.
		SSeasonColdField SeasonCalcColdFieldFromWinterLines( float2 MapCoords, float WinterLineNorth, float WinterLineSouth, float CarveStrength )
		{
			SSeasonColdField Field;

			float WinterNorth = SeasonGetWinterAmount( _SeasonPhase );
			float WinterSouth = SeasonGetWinterAmount( frac( _SeasonPhase + 0.5 ) );

			if ( _SeasonForceFullWinter > 0.5 )
			{
				WinterNorth = 1.0;
				WinterSouth = 1.0;
			}

			Field._LineNorth = WinterLineNorth + _SeasonSnowRetractDistance * ( 1.0 - WinterNorth );
			Field._LineSouth = WinterLineSouth - _SeasonSnowRetractDistance * ( 1.0 - WinterSouth );

			// Painted carve mask: a signed offset on the snow lines for shapes the 1D curves cannot make. The ice passes zero; spill past the coastline is 8-bit noise, not authored lines.
			if ( CarveStrength > 0.0 )
			{
				float Carve = ( PdxTex2D( SnowCarveMaskTexture, float2( MapCoords.x, 1.0 - MapCoords.y ) ).r - 0.5 ) * 2.0 * CarveStrength;
				Field._LineNorth -= Carve;
				Field._LineSouth += Carve;
			}

			Field._Noise = 0.0;
			Field._Latitude = MapCoords.y; // 1 = north pole, 0 = equator on this map

			Field._FadeNorth = smoothstep( 0.0, SEASONS_SNOW_MELT_FADE_END, WinterNorth );
			// No southern hemisphere: disable its snow, frost and sea ice regardless of curve settings or winter preview.
			Field._FadeSouth = 0.0;

			return Field;
		}

		// The snow's deep-winter lines, read from the curve strip; curve edits stay live because the strip is rebuilt the frame a control point moves.
		SSeasonColdField SeasonCalcColdFieldBase( float2 MapCoords )
		{
			float2 WinterLines = PdxTex2D( SeasonCurveTexture, float2( MapCoords.x, 0.5 ) ).rg;
			return SeasonCalcColdFieldFromWinterLines( MapCoords, WinterLines.x, WinterLines.y, _SeasonSnowCarveStrength );
		}

		// The sea ice's own deep-winter lines, with every other field mechanic shared with the snow.
		SSeasonColdField SeasonCalcIceColdFieldBase( float2 MapCoords )
		{
			float2 WinterLines = PdxTex2D( SeasonCurveTexture, float2( MapCoords.x, 0.5 ) ).ba;
			return SeasonCalcColdFieldFromWinterLines( MapCoords, WinterLines.x, WinterLines.y, 0.0 );
		}

		// The unfiltered field, for consumers that add it rather than threshold it, where fading to the mean at distance is the wanted behaviour.
		float SeasonCalcFieldNoise( float2 MapCoords, float NoiseScale, float NoiseOctaves, float NoiseGain )
		{
			float NoiseTiles = SeasonNoiseTiles( NoiseScale );
			float2 NoiseUV = SeasonNoiseBaseUV( MapCoords ) * NoiseTiles;
			return SeasonFractalNoise( NoiseUV, NoiseTiles, NoiseOctaves, NoiseGain );
		}

		// 0..1 coverage of each hemisphere's cold field (x north, y south), with the lines pushed LineOffset toward the equator.
		float2 SeasonCalcColdCoveragePerHemisphere( SSeasonColdField Field, float LineOffset, float EdgeWidth )
		{
			float LineNorth = Field._LineNorth - LineOffset;
			float LineSouth = Field._LineSouth + LineOffset;
			float HalfEdge = max( EdgeWidth, 0.0001 ) * 0.5;
			float North = smoothstep( LineNorth - HalfEdge, LineNorth + HalfEdge, Field._Latitude ) * Field._FadeNorth;
			float South = smoothstep( LineSouth + HalfEdge, LineSouth - HalfEdge, Field._Latitude ) * Field._FadeSouth;
			return float2( North, South );
		}

		// 0..1 coverage of the cold field, with the lines pushed LineOffset toward the equator.
		float SeasonCalcColdCoverage( SSeasonColdField Field, float LineOffset, float EdgeWidth )
		{
			float2 Coverage = SeasonCalcColdCoveragePerHemisphere( Field, LineOffset, EdgeWidth );
			return max( Coverage.x, Coverage.y );
		}

		// The foliage bands reach far enough to cross the equator, so each hemisphere reads only its own cold field; max() let southern winter paint spring into northern June.
		float SeasonCalcOwnHemisphereColdCoverage( SSeasonColdField Field, float LineOffset, float EdgeWidth )
		{
			float2 Coverage = SeasonCalcColdCoveragePerHemisphere( Field, LineOffset, EdgeWidth );
			return SeasonBlendHemispheres( Field._Latitude, Coverage.y, Coverage.x );
		}

		float SeasonCalcHeightLead( SSeasonColdField Field, float3 WorldSpacePos )
		{
			float GroundHeight = GetHeight( WorldSpacePos.xz ) + Field._Noise * _SeasonSnowHeightNoiseAmplitude;
			return smoothstep( SEASONS_SNOW_HEIGHT_MIN, SEASONS_SNOW_HEIGHT_MAX, GroundHeight ) * _SeasonSnowHeightLead;
		}

		float SeasonCalcPatchMask( float2 MapCoords, float Scale, float Octaves, float Gain, float Coverage, float Softness, float EdgeStyleNoise, float EdgeStyleAmplitude )
		{
			float PatchTiles = SeasonNoiseTiles( Scale );
			float2 PatchUV = SeasonNoiseBaseUV( MapCoords ) * PatchTiles;
			float PatchNoise = SeasonFractalNoise( PatchUV, PatchTiles, Octaves, Gain );
			float PatchCut = 1.0 - 2.0 * Coverage;
			// Noise units to latitude through the field's typical gradient, so the softness is a band width in the same units as the coverage edge widths.
			float PatchDistance = ( PatchNoise - PatchCut ) / ( PatchTiles * SEASONS_MAP_ASPECT * SEASONS_PATCH_NOISE_GRADIENT );
			float PatchSoftness = max( Softness, 0.0001 );
			float PatchMask = smoothstep( -PatchSoftness, PatchSoftness, PatchDistance );
			// The snow line's edge construction on the patch outline: the wobble adds in coverage, confined by a window closing at both ends so it reshapes a border but never opens or closes one.
			return saturate( PatchMask + EdgeStyleNoise * EdgeStyleAmplitude * saturate( 4.0 * PatchMask * ( 1.0 - PatchMask ) ) );
		}

		// The baked noise textures share the ice distance fields' orientation: rows run north to south.
		float2 SeasonNoiseUV( float2 MapCoords )
		{
			return float2( MapCoords.x, 1.0 - MapCoords.y );
		}

		// The two noise textures channel by channel, written by the bake and evaluated per pixel by the panel's live toggle. Signed noises sit around 0.5.
		// Ice: red ice line wobble, green ice lane wobble, blue snow patch mask on the ice, alpha snow line noise.
		float4 SeasonCalcIceNoiseFields( float2 MapCoords )
		{
			float LineNoise = SeasonCalcFieldNoise( MapCoords, _SeasonIceLineNoiseScale, _SeasonIceLineNoiseOctaves, _SeasonIceLineNoiseGain );
			// The lane banks wobble with a fixed three-octave fBm; the carve applies the amplitude where it reads this.
			float LaneNoise = SeasonCalcFieldNoise( MapCoords, _SeasonIceLaneNoiseScale, 3.0, 0.5 );
			float SnowNoise = SeasonCalcFieldNoise( MapCoords, _SeasonSnowNoiseScale, _SeasonSnowNoiseOctaves, _SeasonSnowNoiseGain );
			float IcePatchMask = SeasonCalcPatchMask( MapCoords, _SeasonIceSnowPatchScale, _SeasonIceSnowPatchOctaves, _SeasonIceSnowPatchGain, _SeasonIceSnowPatchCoverage, _SeasonIceSnowPatchSoftness, SnowNoise, _SeasonSnowNoiseAmplitude );
			return float4( saturate( LineNoise * 0.5 + 0.5 ), saturate( LaneNoise * 0.5 + 0.5 ), IcePatchMask, saturate( SnowNoise * 0.5 + 0.5 ) );
		}

		// Terrain: red frost line noise, green snow patch mask, blue autumn patch mask, alpha spring patch mask. The snow line noise styles every patch outline.
		float4 SeasonCalcTerrainNoiseFields( float2 MapCoords )
		{
			float SnowNoise = SeasonCalcFieldNoise( MapCoords, _SeasonSnowNoiseScale, _SeasonSnowNoiseOctaves, _SeasonSnowNoiseGain );
			float FrostNoise = SeasonCalcFieldNoise( MapCoords, _SeasonFrostNoiseScale, _SeasonFrostNoiseOctaves, _SeasonFrostNoiseGain );
			float SnowPatchMask = SeasonCalcPatchMask( MapCoords, _SeasonSnowPatchScale, _SeasonSnowPatchOctaves, _SeasonSnowPatchGain, _SeasonSnowPatchCoverage, _SeasonSnowPatchSoftness, SnowNoise, _SeasonSnowNoiseAmplitude );
			float FallPatchMask = SeasonCalcPatchMask( MapCoords, _SeasonFallPatchScale, _SeasonFallPatchOctaves, _SeasonFallPatchGain, _SeasonFallPatchCoverage, _SeasonFallPatchSoftness, SnowNoise, _SeasonSnowNoiseAmplitude );
			float SpringPatchMask = SeasonCalcPatchMask( MapCoords, _SeasonSpringPatchScale, _SeasonSpringPatchOctaves, _SeasonSpringPatchGain, _SeasonSpringPatchCoverage, _SeasonSpringPatchSoftness, SnowNoise, _SeasonSnowNoiseAmplitude );
			return float4( saturate( FrostNoise * 0.5 + 0.5 ), SnowPatchMask, FallPatchMask, SpringPatchMask );
		}

		// Shipped builds read the bakes. The season panel's live toggle adds the SEASONS_LIVE_NOISE define and reloads the effects, so the fields are
		// evaluated per pixel while tuning and no other build compiles that path.
		float4 SeasonIceNoiseAt( float2 MapCoords )
		{
			#ifdef SEASONS_LIVE_NOISE
			return SeasonCalcIceNoiseFields( MapCoords );
			#else
			return PdxTex2D( SeasonNoiseTexture, SeasonNoiseUV( MapCoords ) );
			#endif
		}

		float4 SeasonTerrainNoiseAt( float2 MapCoords )
		{
			#ifdef SEASONS_LIVE_NOISE
			return SeasonCalcTerrainNoiseFields( MapCoords );
			#else
			return PdxTex2D( SeasonTerrainNoiseTexture, SeasonNoiseUV( MapCoords ) );
			#endif
		}

		float2 SeasonPlacementMaskAt( float2 MapCoords )
		{
			return PdxTex2D( SeasonPlacementMaskTexture, SeasonNoiseUV( MapCoords ) ).rg;
		}

		float SeasonSnowLineNoiseAt( float2 MapCoords )
		{
			#ifdef SEASONS_LIVE_NOISE
			return SeasonCalcFieldNoise( MapCoords, _SeasonSnowNoiseScale, _SeasonSnowNoiseOctaves, _SeasonSnowNoiseGain );
			#else
			return PdxTex2D( SeasonNoiseTexture, SeasonNoiseUV( MapCoords ) ).a * 2.0 - 1.0;
			#endif
		}

		void SeasonCalcSnowAndFrost( float2 MapCoords, float3 WorldSpacePos, out float SnowCoverage, out float FrostCoverage, out float FallSupport, out float SpringSupport, out float LineNoise )
		{
			SnowCoverage = 0.0;
			FrostCoverage = 0.0;
			FallSupport = 0.0;
			SpringSupport = 0.0;
			LineNoise = 0.0;
			if ( _SeasonsStrength <= 0.0 )
			{
				return;
			}

			SSeasonColdField Field = SeasonCalcColdFieldBase( MapCoords );

			// Every ramp below ends within this reach of the deep-winter line. Past it all five outputs are zero, so the warm side skips the noise fetches, the heightmap and the ramps.
			float FoliageReach = max( _SeasonFallMargin + _SeasonFallEdgeWidth, _SeasonSpringMargin + _SeasonSpringEdgeWidth ) * _SeasonFoliageEnabled;
			float MaxReach = max( max( FoliageReach, _SeasonFrostMargin + _SeasonFrostEdgeWidth * 0.5 ), _SeasonSnowEdgeWidth * 0.5 ) + max( _SeasonSnowHeightLead, 0.0 );
			if ( SeasonCalcColdCoverage( Field, MaxReach, 0.0002 ) <= 0.0 )
			{
				return;
			}

			float SnowNoise = 0.0;
			if ( _SeasonSnowNoiseAmplitude > 0.0 || _SeasonSnowHeightNoiseAmplitude > 0.0 )
			{
				SnowNoise = SeasonSnowLineNoiseAt( MapCoords );
			}
			LineNoise = SnowNoise;
			Field._Noise = SnowNoise;
			float HeightLead = SeasonCalcHeightLead( Field, WorldSpacePos );
			float4 TerrainNoise = SeasonTerrainNoiseAt( MapCoords );

			// Added in coverage: the reach scales with the edge softness, and the window closes at both ramp ends so it cannot hole the saturated field.
			float SnowCold = SeasonCalcColdCoverage( Field, HeightLead, _SeasonSnowEdgeWidth );
			SnowCoverage = saturate( SnowCold + SnowNoise * _SeasonSnowNoiseAmplitude * saturate( 4.0 * SnowCold * ( 1.0 - SnowCold ) ) );

			// Carves openings into the filled snow only, leaving the edge band to the line noise.
			if ( _SeasonSnowPatchStrength > 0.0 )
			{
				// A ramp displaced poleward, not a threshold on the coverage, which saturates a short way inland and would hand over across a thin seam.
				float PatchInterior = SeasonCalcColdCoverage( Field, HeightLead - _SeasonSnowPatchInlandStart, _SeasonSnowEdgeWidth );
				if ( PatchInterior > 0.0 )
				{
					SnowCoverage = saturate( SnowCoverage - TerrainNoise.g * _SeasonSnowPatchStrength * PatchInterior );
				}
			}

			if ( _SeasonFrostOpacity > 0.0 )
			{
				float FrostNoise = TerrainNoise.r * 2.0 - 1.0;
				float FrostCold = SeasonCalcColdCoverage( Field, _SeasonFrostMargin + HeightLead, _SeasonFrostEdgeWidth );
				FrostCoverage = saturate( FrostCold + FrostNoise * _SeasonFrostNoiseAmplitude * saturate( 4.0 * FrostCold * ( 1.0 - FrostCold ) ) );
			}

			// A trapezoid anchored at both full ends: rise over one edge width, hold to the margin, fall over another, so the softness can never pull the full reach back.
			float FallOut = SeasonCalcOwnHemisphereColdCoverage( Field, _SeasonFallMargin + HeightLead + _SeasonFallEdgeWidth * 0.5, _SeasonFallEdgeWidth );
			float FallIn = 1.0 - SeasonCalcOwnHemisphereColdCoverage( Field, HeightLead + _SeasonFallEdgeWidth * 0.5, _SeasonFallEdgeWidth );
			FallSupport = FallOut * FallIn * _SeasonFoliageEnabled;
			float SpringOut = SeasonCalcOwnHemisphereColdCoverage( Field, _SeasonSpringMargin + HeightLead + _SeasonSpringEdgeWidth * 0.5, _SeasonSpringEdgeWidth );
			float SpringIn = 1.0 - SeasonCalcOwnHemisphereColdCoverage( Field, HeightLead + _SeasonSpringEdgeWidth * 0.5, _SeasonSpringEdgeWidth );
			SpringSupport = SpringOut * SpringIn * _SeasonFoliageEnabled;

			// Devastation burns the season off the ground: snow and rime melt, and scorched ground takes no autumn or spring colour. The unclamped field is read so the
			// melt saturates where the terrain's own blend stops at Area_Max, and its noise gives the melt the same ragged edge as the scorching.
			float Devastation = GetDevastation( MapCoords );
			if ( Devastation > 0.0 )
			{
				float Melt = 1.0 - saturate( Devastation * SEASONS_DEVASTATION_MELT );
				SnowCoverage *= Melt;
				FrostCoverage *= Melt;
				FallSupport *= Melt;
				SpringSupport *= Melt;
			}
		}

		// The contour lives in screen space: distance to the 0.5 level in pixels, faded over half a pixel, so the stripe keeps an even antialiased width whatever the field's steepness.
		float SeasonDebugContourStripe( float Value )
		{
			float PixelDistance = abs( Value - 0.5 ) / max( abs( ddx( Value ) ) + abs( ddy( Value ) ), 0.0001 );
			return ( 1.0 - smoothstep( 1.5, 2.0, PixelDistance ) ) * step( abs( Value - 0.5 ), 0.05 );
		}

		// A flat wash for surfaces the snow material cannot reach; on something as narrow as a road the height blend only wins a strip at each shoulder.
		void SeasonApplySnowTint( inout float3 Color, float Amount )
		{
			float3 Tint = float3( _SeasonSnowTintRed, _SeasonSnowTintGreen, _SeasonSnowTintBlue );
			Color = lerp( Color, Tint, saturate( Amount * _SeasonSnowTintStrength ) );
		}

		float3 SeasonFrostColor()
		{
			return float3( _SeasonFrostColorRed, _SeasonFrostColorGreen, _SeasonFrostColorBlue );
		}

		float3 SeasonFrostRime( float3 BaseColor )
		{
			float Luminance = SeasonLuminance( BaseColor );
			float3 Rime = lerp( BaseColor, float3( Luminance, Luminance, Luminance ), _SeasonFrostDesaturate );
			Rime = saturate( Rime * _SeasonFrostBrighten );
			return lerp( Rime, SeasonFrostColor(), _SeasonFrostRimeTint );
		}

		// Snow presence for effects that only need to know whether the ground is white: half coverage on the line, full inside it, fading out across the frost band that leads it.
		float SeasonCalcSnowLineCoverage( float2 MapCoords )
		{
			if ( _SeasonsStrength <= 0.0 )
			{
				return 0.0;
			}

			SSeasonColdField Field = SeasonCalcColdFieldBase( MapCoords );
			float Coverage = SeasonCalcColdCoverage( Field, 0.0, _SeasonFrostEdgeWidth );
			// The wobble only acts inside the edge window; a saturated or empty ramp skips the fetch.
			if ( _SeasonSnowNoiseAmplitude > 0.0 && Coverage > 0.0 && Coverage < 1.0 )
			{
				float SnowNoise = SeasonSnowLineNoiseAt( MapCoords );
				Coverage = saturate( Coverage + SnowNoise * _SeasonSnowNoiseAmplitude * saturate( 4.0 * Coverage * ( 1.0 - Coverage ) ) );
			}
			return Coverage;
		}
	]]
}
