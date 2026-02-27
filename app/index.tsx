import { LinearGradient } from 'expo-linear-gradient';
import { useRouter } from 'expo-router';
import { useEffect, useRef } from 'react';
import { Animated, Easing, Image, ImageBackground, StyleSheet, Text, TouchableOpacity, View } from 'react-native';

export default function HomeScreen() {
  const router = useRouter();

  const logoAnim = useRef(new Animated.Value(0)).current;
  const buttonAnim = useRef(new Animated.Value(0)).current;
  const glowAnim = useRef(new Animated.Value(0.4)).current;

  useEffect(() => {
    Animated.sequence([
      Animated.timing(logoAnim, {
        toValue: 1,
        duration: 600,
        easing: Easing.out(Easing.cubic),
        useNativeDriver: true,
      }),
      Animated.timing(buttonAnim, {
        toValue: 1,
        duration: 400,
        easing: Easing.out(Easing.back(1.2)),
        useNativeDriver: true,
      }),
    ]).start(() => {
      Animated.loop(
        Animated.sequence([
          Animated.timing(glowAnim, { toValue: 0.9, duration: 1000, useNativeDriver: false }),
          Animated.timing(glowAnim, { toValue: 0.3, duration: 1000, useNativeDriver: false }),
        ])
      ).start();
    });
  }, []);

  return (
    <ImageBackground
      source={require('../assets/bg.png')}
      style={styles.bg}
      resizeMode="cover"
    >
      <View style={styles.overlay} />
      <View style={styles.container}>
        <View style={styles.brandingContainer}>
          <Animated.View style={{
            opacity: logoAnim,
            transform: [{ scale: logoAnim.interpolate({ inputRange: [0, 1], outputRange: [0.85, 1] }) }],
          }}>
            <Image
              source={require('../assets/logo.png')}
              style={styles.logo}
              resizeMode="contain"
            />
          </Animated.View>
        </View>

        <Animated.View style={{
          opacity: buttonAnim,
          transform: [{ translateY: buttonAnim.interpolate({ inputRange: [0, 1], outputRange: [24, 0] }) }],
          width: '100%',
        }}>
          <Animated.View style={[styles.buttonGlow, { shadowOpacity: glowAnim }]}>
            <TouchableOpacity
              onPress={() => router.push('/setup')}
              activeOpacity={0.85}
              style={styles.newGameBtnOuter}
            >
              <LinearGradient
                colors={['#60ff28', '#3ddc10', '#28a808', '#1a7005']}
                locations={[0, 0.35, 0.7, 1]}
                start={{ x: 0.5, y: 0 }}
                end={{ x: 0.5, y: 1 }}
                style={styles.newGameButton}
              >
                <LinearGradient
                  colors={['rgba(255,255,255,0.12)', 'rgba(255,255,255,0.0)', 'rgba(0,0,0,0.15)']}
                  locations={[0, 0.4, 1]}
                  start={{ x: 0, y: 0.5 }}
                  end={{ x: 1, y: 0.5 }}
                  style={StyleSheet.absoluteFill}
                />
                <LinearGradient
                  colors={['rgba(255,255,255,0.55)', 'rgba(255,255,255,0.15)', 'rgba(255,255,255,0.0)']}
                  locations={[0, 0.4, 1]}
                  start={{ x: 0.5, y: 0 }}
                  end={{ x: 0.5, y: 1 }}
                  style={styles.btnSpecularGrad}
                />
                <View style={styles.btnSpecularDot} />
                <LinearGradient
                  colors={['rgba(0,0,0,0)', 'rgba(0,0,0,0.25)']}
                  start={{ x: 0.5, y: 0 }}
                  end={{ x: 0.5, y: 1 }}
                  style={styles.btnBottomShadow}
                />
                <View style={styles.btnTopEdge} />
                <Text style={styles.newGameText}>Start Round</Text>
              </LinearGradient>
            </TouchableOpacity>
          </Animated.View>
        </Animated.View>
      </View>
    </ImageBackground>
  );
}

const styles = StyleSheet.create({
  bg: {
    flex: 1,
    width: '100%',
  },
  overlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(0,0,0,0.52)',
  },
  container: {
    flex: 1,
    width: '100%',
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 32,
  },
  brandingContainer: {
    alignItems: 'center',
    marginBottom: 40,
  },
  logo: {
    width: 340,
    height: 230,
    marginBottom: 8,
  },
  buttonGlow: {
    shadowColor: '#39FF14',
    shadowOffset: { width: 0, height: 10 },
    shadowOpacity: 0.55,
    shadowRadius: 24,
    elevation: 16,
    borderRadius: 16,
  },
  newGameBtnOuter: {
    width: '100%',
    borderRadius: 16,
  },
  newGameButton: {
    paddingVertical: 20,
    borderRadius: 16,
    width: '100%',
    alignItems: 'center',
    overflow: 'hidden',
    position: 'relative',
  },
  btnSpecularGrad: {
    position: 'absolute',
    top: 0,
    left: '5%',
    right: '5%',
    height: '60%',
    borderTopLeftRadius: 16,
    borderTopRightRadius: 16,
    borderBottomLeftRadius: 60,
    borderBottomRightRadius: 60,
  },
  btnSpecularDot: {
    position: 'absolute',
    top: 5,
    left: '25%',
    width: '30%',
    height: 8,
    borderRadius: 4,
    backgroundColor: 'rgba(255,255,255,0.65)',
  },
  btnBottomShadow: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    height: '40%',
    borderBottomLeftRadius: 16,
    borderBottomRightRadius: 16,
  },
  btnTopEdge: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    height: 1.5,
    backgroundColor: 'rgba(255,255,255,0.55)',
    borderTopLeftRadius: 16,
    borderTopRightRadius: 16,
  },
  newGameText: {
    fontSize: 22,
    fontWeight: '800',
    color: '#000',
    letterSpacing: 0.5,
    zIndex: 2,
  },
});
