import { useRouter } from 'expo-router';
import { useEffect, useRef } from 'react';
import { Animated, Easing, Image, StyleSheet, Text, TouchableOpacity, View } from 'react-native';

export default function HomeScreen() {
  const router = useRouter();

  // Animation values
  const logoAnim = useRef(new Animated.Value(0)).current;
  const taglineAnim = useRef(new Animated.Value(0)).current;
  const buttonAnim = useRef(new Animated.Value(0)).current;
  const glowAnim = useRef(new Animated.Value(0.4)).current;

  useEffect(() => {
    Animated.sequence([
      // 1. Logo fades + scales in
      Animated.timing(logoAnim, {
        toValue: 1,
        duration: 600,
        easing: Easing.out(Easing.cubic),
        useNativeDriver: true,
      }),
      // 2. Tagline fades up
      Animated.timing(taglineAnim, {
        toValue: 1,
        duration: 400,
        easing: Easing.out(Easing.quad),
        useNativeDriver: true,
      }),
      // 3. Button slides up
      Animated.timing(buttonAnim, {
        toValue: 1,
        duration: 400,
        easing: Easing.out(Easing.back(1.2)),
        useNativeDriver: true,
      }),
    ]).start(() => {
      // 4. After everything is in, start glow pulse loop on button
      Animated.loop(
        Animated.sequence([
          Animated.timing(glowAnim, { toValue: 0.9, duration: 1000, useNativeDriver: false }),
          Animated.timing(glowAnim, { toValue: 0.3, duration: 1000, useNativeDriver: false }),
        ])
      ).start();
    });
  }, []);

  return (
    <View style={styles.container}>
      <View style={styles.brandingContainer}>
        <Animated.View style={{
          opacity: logoAnim,
          transform: [{ scale: logoAnim.interpolate({ inputRange: [0, 1], outputRange: [0.85, 1] }) }],
        }}>
          <Image
            source={require('../assets/logo.jpg')}
            style={styles.logo}
            resizeMode="contain"
          />
        </Animated.View>

        <Animated.Text style={[styles.tagline, {
          opacity: taglineAnim,
          transform: [{ translateY: taglineAnim.interpolate({ inputRange: [0, 1], outputRange: [8, 0] }) }],
        }]}>
          Bet that.
        </Animated.Text>
      </View>

      <Animated.View style={{
        opacity: buttonAnim,
        transform: [{ translateY: buttonAnim.interpolate({ inputRange: [0, 1], outputRange: [24, 0] }) }],
        width: '100%',
      }}>
        <Animated.View style={[styles.buttonGlow, {
          shadowOpacity: glowAnim,
        }]}>
          <TouchableOpacity
            style={styles.newGameButton}
            onPress={() => router.push('/setup')}
            activeOpacity={0.8}
          >
            <Text style={styles.newGameText}>Start Round</Text>
          </TouchableOpacity>
        </Animated.View>
      </Animated.View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#000',
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 32,
  },
  brandingContainer: {
    alignItems: 'center',
    marginBottom: 40,
  },
  logo: {
    width: 280,
    height: 200,
    marginBottom: 16,
  },
  tagline: {
    fontSize: 20,
    color: '#888888',
    marginTop: 4,
    textAlign: 'center',
  },
  buttonGlow: {
    shadowColor: '#39FF14',
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0.4,
    shadowRadius: 20,
    elevation: 12,
    borderRadius: 16,
  },
  newGameButton: {
    backgroundColor: '#39FF14',
    paddingVertical: 20,
    paddingHorizontal: 64,
    borderRadius: 16,
    width: '100%',
    alignItems: 'center',
  },
  newGameText: {
    fontSize: 22,
    fontWeight: '800',
    color: '#000',
    letterSpacing: 0.5,
  },
});
