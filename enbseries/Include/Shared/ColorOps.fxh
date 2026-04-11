/*  //////////////////////////////////////////////////////////////////////////////////  **

	General color operation functions

**  //////////////////////////////////////////////////////////////////////////////////  */


float3 SRGBToLinear(float3 SRGB)
{
    return (SRGB < 0.04045)
         ?  SRGB / 12.92
         :  pow(abs((SRGB + 0.055) / 1.055), 2.4);
}

float3 LinearToSRGB(float3 LinearColor)
{
    return (LinearColor < 0.0031308)
         ?  12.92 * LinearColor
         :  1.055 * pow(abs(LinearColor), 1.0 / 2.4) - 0.055;
}

float3 RGBToHSL(float3 color)
{
	float3 hsl; // init to 0 to avoid warnings ? (and reverse if + remove first part)

	float fmin = min(min(color.r, color.g), color.b);    //Min. value of RGB
	float fmax = max(max(color.r, color.g), color.b);    //Max. value of RGB
	float delta = fmax - fmin;             //Delta RGB value

	hsl.z = (fmax + fmin) / 2.0; // Luminance

	if (delta == 0.0)		//This is a gray, no chroma...
	{
		hsl.x = 0.0;	// Hue
		hsl.y = 0.0;	// Saturation
	}

	else                                    //Chromatic data...
	{
		if (hsl.z < 0.5)
			hsl.y = delta / (fmax + fmin); // Saturation
		else
			hsl.y = delta / (2.0 - fmax - fmin); // Saturation

		float deltaR = (((fmax - color.r) / 6.0) + (delta / 2.0)) / delta;
		float deltaG = (((fmax - color.g) / 6.0) + (delta / 2.0)) / delta;
		float deltaB = (((fmax - color.b) / 6.0) + (delta / 2.0)) / delta;

		if (color.r == fmax )
			hsl.x = deltaB - deltaG; // Hue
		else if (color.g == fmax)
			hsl.x = (1.0 / 3.0) + deltaR - deltaB; // Hue
		else if (color.b == fmax)
			hsl.x = (2.0 / 3.0) + deltaG - deltaR; // Hue

		if (hsl.x < 0.0)
			hsl.x += 1.0; // Hue
		else if (hsl.x > 1.0)
			hsl.x -= 1.0; // Hue
	}

	return hsl;
}

float HueToRGB(float f1, float f2, float hue)
{
	if (hue < 0.0)
		hue += 1.0;
	else if (hue > 1.0)
		hue -= 1.0;

	float res;
	if ((6.0 * hue) < 1.0)
		res = f1 + (f2 - f1) * 6.0 * hue;
	else if ((2.0 * hue) < 1.0)
		res = f2;
	else if ((3.0 * hue) < 2.0)
		res = f1 + (f2 - f1) * ((2.0 / 3.0) - hue) * 6.0;
	else
		res = f1;

	return res;
}

float3 HSLToRGB(float3 hsl)
{
	float3 rgb;

	if (hsl.y == 0.0)
		rgb = float3(hsl.z, hsl.z, hsl.z); // Luminance

	else
	{
		float f2;

		if (hsl.z < 0.5)
			f2 = hsl.z * (1.0 + hsl.y);
		else
			f2 = (hsl.z + hsl.y) - (hsl.y * hsl.z);

		float f1 = 2.0 * hsl.z - f2;

		rgb.r = HueToRGB(f1, f2, hsl.x + (1.0/3.0));
		rgb.g = HueToRGB(f1, f2, hsl.x);
		rgb.b= HueToRGB(f1, f2, hsl.x - (1.0/3.0));
	}

	return rgb;
}

float3 HUEtoRGB(float H)
{
    float R = abs(H * 6 - 3) - 1;
    float G = 2 - abs(H * 6 - 2);
    float B = 2 - abs(H * 6 - 4);

    return saturate(float3(R,G,B));
}


float RGBCVtoHUE(float3 RGB, float C, float V)
{
    float3 Delta = (V - RGB) / C;
    Delta.rgb -= Delta.brg;
    Delta.rgb += float3(2,4,6);

    // NOTE 1
    Delta.brg = step(V, RGB) * Delta.brg;
    float H;

    H = max(Delta.r, max(Delta.g, Delta.b));

    return frac(H / 6);
}

float3 RGBToHSV(float3 RGB)
{
    float3 HSV = 0;
    HSV.z = max(RGB.r, max(RGB.g, RGB.b));

    float M = min(RGB.r, min(RGB.g, RGB.b));
    float C = HSV.z - M;

    if (C != 0)
    {
        HSV.x = RGBCVtoHUE(RGB, C, HSV.z);
        HSV.y = C / HSV.z;
    }

  return HSV;
}


float3 HSVToRGB(float3 HSV)
{
    float3 RGB = HUEtoRGB(HSV.x);

    return ((RGB - 1) * HSV.y + 1) * HSV.z;
}

float4 RGBToCMYK(float3 rgb)
{
    float K = 1.0 - max(max(rgb.r, rgb.g), rgb.b);

    return float4(saturate((1.0 - rgb.r - K) / (1.0 - K)),
                  saturate((1.0 - rgb.g - K) / (1.0 - K)),
                  saturate((1.0 - rgb.b - K) / (1.0 - K)),
                  K);
}

float3 CMYKToRGB(float4 cmyk)
{
    return float3((1.0 - cmyk.x) * (1.0 - cmyk.w),
		          (1.0 - cmyk.y) * (1.0 - cmyk.w),
		          (1.0 - cmyk.z) * (1.0 - cmyk.w));
}

static const float PQ_constant_N = (2610.0 / 4096.0 / 4.0);
static const float PQ_constant_M = (2523.0 / 4096.0 * 128.0);
static const float PQ_constant_C1 = (3424.0 / 4096.0);
static const float PQ_constant_C2 = (2413.0 / 4096.0 * 32.0);
static const float PQ_constant_C3 = (2392.0 / 4096.0 * 32.0);

// PQ (Perceptual Quantiser; ST.2084) encode/decode used for HDR TV and grading
float3 linearToPQ(float3 linearCol, const float maxPqValue)
{
    linearCol /= maxPqValue;
    float3 colToPow = pow(linearCol, PQ_constant_N);
    float3 numerator = PQ_constant_C1 + PQ_constant_C2*colToPow;
    float3 denominator = 1.0 + PQ_constant_C3*colToPow;
    float3 pq = pow(numerator / denominator, PQ_constant_M);
    return pq;
}

float3 PQtoLinear(float3 linearCol, const float maxPqValue)
{
    float3 colToPow = pow(linearCol, 1.0 / PQ_constant_M);
    float3 numerator = max(colToPow - PQ_constant_C1, 0.0);
    float3 denominator = PQ_constant_C2 - (PQ_constant_C3 * colToPow);
    float3 linearColor = pow(numerator / denominator, 1.0 / PQ_constant_N);
    linearColor *= maxPqValue;
    return linearColor;
}

// RGB with sRGB/Rec.709 primaries to CIE XYZ
float3 RGBToXYZ(float3 c)
{
    float3x3 mat = float3x3(0.4124564, 0.3575761, 0.1804375,
                            0.2126729, 0.7151522, 0.0721750,
                            0.0193339, 0.1191920, 0.9503041);
    return mul(mat, c);
}

float3 XYZToRGB(float3 c)
{
    float3x3 mat = float3x3(3.24045483602140870, -1.53713885010257510, -0.49853154686848090,
                           -0.96926638987565370,  1.87601092884249100,  0.04155608234667354,
                            0.05564341960421366, -0.20402585426769815,  1.05722516245792870);
    return mul(mat, c);
}

// Converts XYZ tristimulus values into cone responses for the three types of cones in the human 
// visual system, matching long, medium, and short wavelengths.
// Note that there are many LMS color spaces; this one follows the ICtCp color space specification.
float3 XYZToLMS(float3 c)
{
    float3x3 mat = float3x3(0.3592, 0.6976, -0.0358,
                           -0.1922, 1.1004,  0.0755,
                            0.0070, 0.0749,  0.8434);
    return mul(mat, c);
}

float3 LMSToXYZ(float3 c)
{
    float3x3 mat = float3x3(2.07018005669561320, -1.32645687610302100,  0.206616006847855170,
                            0.36498825003265756,  0.68046736285223520, -0.045421753075853236,
                           -0.04959554223893212, -0.04942116118675749,  1.187995941732803400);
    return mul(mat, c);
}

// RGB with sRGB/Rec.709 primaries to ICtCp
float3 RGBToICtCp(float3 col)
{
    col = RGBToXYZ(col);
    col = XYZToLMS(col);

    // 1.0f = 100 nits, 100.0f = 10k nits
    col = linearToPQ(max(0.0.xxx, col), 100.0);

    // Convert PQ-LMS into ICtCp. Note that the "S" channel is not used,
    // but overlap between the cone responses for long, medium, and short wavelengths
    // ensures that the corresponding part of the spectrum contributes to luminance.
    float3x3 mat = float3x3(0.5000,  0.5000,  0.0000,
                            1.6137, -3.3234,  1.7097,
                            4.3780, -4.2455, -0.1325);
    return mul(mat, col);
}

float3 ICtCpToRGB(float3 col)
{
    float3x3 mat = float3x3(1.0, 0.00860514569398152, 0.11103560447547328,
                            1.0, -0.00860514569398152, -0.11103560447547328,
                            1.0, 0.56004885956263900, -0.32063747023212210);
    col = mul(mat, col);

    // 1.0f = 100 nits, 100.0f = 10k nits
    col = PQtoLinear(col, 100.0);
    col = LMSToXYZ(col);

    return XYZToRGB(col);
}

float3 SmartSaturation(float3 color, int saturation)
{
	float3 orig;
	float  sat, lum, mask;

	lum      =  GetLuma(color);
	mask     =  smoothstep(0.9, 0.0, lum);
	sat      =  pow(RGBToHSL(color).y, 0.75);

	color    = (saturation < 101)
	         ?  lerp(lum, color, saturation * 0.01)
		     :  lerp(color, lerp(lum, color, 2.0), mask * sat * ((saturation - 100) * 0.01));

	return color;
}

float3 ColorTemperatureToRGB(float temperatureInKelvins)
{
	float3 retColor;

    temperatureInKelvins = clamp(temperatureInKelvins, 1000.0, 40000.0) / 100.0;

    if (temperatureInKelvins <= 66.0)
    {
        retColor.r = 1.0;
        retColor.g = clamp(0.39008157876901960784 * log(temperatureInKelvins) - 0.63184144378862745098, 0.0, 30000.0);
    }

    else
    {
    	float t = temperatureInKelvins - 60.0;
        retColor.r = clamp(1.29293618606274509804 * pow(abs(t), -0.1332047592), 0.0, 30000.0);
        retColor.g = clamp(1.12989086089529411765 * pow(abs(t), -0.0755148492), 0.0, 30000.0);
    }

    if (temperatureInKelvins >= 66.0)
	{
		retColor.b = 1.0;
	}
        
    else if (temperatureInKelvins <= 19.0)
	{
		retColor.b = 0.0;
	}
        
    else
	{
		retColor.b = clamp(0.54320678911019607843 * log(temperatureInKelvins - 10.0) - 1.19625408914, 0.0, 30000.0);
	}
        
    return retColor;
}

float3 Kelvin(float3 color, float kelvin)
{
    float3 ktemp, result, hsl, lumablend;
    float luma;

    ktemp     = ColorTemperatureToRGB(kelvin);

	luma      = GetLuma(color);

	result    = color * ktemp;

	hsl       = RGBToHSL(result);
	lumablend = HSLToRGB(float3(hsl.x, hsl.y, luma));

	return lerp(result, lumablend, 0.75);
}

float3 WhiteBalance(float3 color, float scene, float cam, int lum)
{
    float kelvin, luma;

    // Normalize kelvin input (6500 = no change to image)
    kelvin = 6500 + ((6500 - cam) + (scene - 6500));

    // Store image luma
    luma   = dot(color, float3(0.212395, 0.701049, 0.086556));

    // Apply the whitebalance
	color /= lerp(1.0, luma, lum); // Optional luma preservation
    color *= ColorTemperatureToRGB(kelvin); // Apply color temp
	color *= lerp(1.0, luma, lum); // Optional luma preservation

    return color;
}
