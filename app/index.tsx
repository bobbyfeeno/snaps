import { useRouter } from 'expo-router';
import { Image, StyleSheet, Text, TouchableOpacity, View } from 'react-native';

export default function HomeScreen() {
  const router = useRouter();

  return (
    <View style={styles.container}>
      <View style={styles.brandingContainer}>
        <Image
          source={require('../assets/logo.jpg')}
          style={styles.logo}
          resizeMode="contain"
        />
        <Text style={styles.tagline}>Beat your number. Collect the cash.</Text>
      </View>

      <View style={styles.decorLines}>
        <View style={styles.line} />
        <Text style={styles.flagEmoji}>⛳</Text>
        <View style={styles.line} />
      </View>

      <TouchableOpacity
        style={styles.newGameButton}
        onPress={() => router.push('/setup')}
        activeOpacity={0.8}
      >
        <Text style={styles.newGameText}>New Game</Text>
      </TouchableOpacity>

      <Text style={styles.rulesHint}>
        Shoot below your Tax Man to win
      </Text>

      <TouchableOpacity
        onPress={() => router.push('/scores?preview=true')}
        style={styles.previewLink}
        activeOpacity={0.7}
      >
        <Text style={styles.previewLinkText}>👀 Preview Scorecard</Text>
      </TouchableOpacity>
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
    fontSize: 16,
    color: '#88bb88',
    marginTop: 4,
    textAlign: 'center',
  },
  decorLines: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 48,
    width: '100%',
  },
  line: {
    flex: 1,
    height: 1,
    backgroundColor: '#1a1a1a',
  },
  flagEmoji: {
    fontSize: 28,
    marginHorizontal: 16,
  },
  newGameButton: {
    backgroundColor: '#39FF14',
    paddingVertical: 20,
    paddingHorizontal: 64,
    borderRadius: 16,
    width: '100%',
    alignItems: 'center',
    shadowColor: '#39FF14',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.5,
    shadowRadius: 16,
    elevation: 10,
  },
  newGameText: {
    fontSize: 22,
    fontWeight: '800',
    color: '#000',
    letterSpacing: 0.5,
  },
  rulesHint: {
    marginTop: 24,
    fontSize: 14,
    color: '#5a8a5a',
    textAlign: 'center',
  },
  previewLink: {
    marginTop: 32,
    paddingVertical: 12,
  },
  previewLinkText: {
    fontSize: 14,
    color: '#5a8a5a',
    textAlign: 'center',
  },
});
