String bannerRecommendedDimensions(String placement) =>
    placement == 'popup' ? '1080 × 1920 px' : '1280 × 400 px';

double bannerFrameAspectRatio(String placement) =>
    placement == 'popup' ? 9 / 16 : 3.2;
