import { GlassView } from 'expo-glass-effect';
import { LinearGradient } from 'expo-linear-gradient';
import React from 'react';
import { StyleProp, StyleSheet, View, ViewStyle } from 'react-native';

interface BevelCardProps {
  children: React.ReactNode;
  style?: StyleProp<ViewStyle>;
  active?: boolean; // green-tinted variant
}

export function BevelCard({ children, style, active = false }: BevelCardProps) {
  const gradColors: [string, string, string] = active
    ? ['#1e2e12', '#131f0c', '#0b1507']
    : ['#262626', '#1a1a1a', '#101010'];

  return (
    <View style={[styles.outerShadow, style]}>
      <LinearGradient colors={gradColors} locations={[0, 0.5, 1]} style={styles.card}>
        {/* Top highlight */}
        <View style={styles.edgeTop} />
        {/* Left bevel */}
        <View style={styles.edgeLeft} />
        {/* Right bevel */}
        <View style={styles.edgeRight} />
        {/* Bottom inner shadow */}
        <View style={styles.edgeBottom} />
        {/* Native glass overlay */}
        <GlassView
          style={[StyleSheet.absoluteFill, { borderRadius: 16, overflow: 'hidden' }]}
          glassEffectStyle="regular"
          colorScheme="dark"
          tintColor={active ? 'rgba(57,255,20,0.12)' : 'rgba(20,20,20,0.25)'}
        />
        {children}
      </LinearGradient>
    </View>
  );
}

const styles = StyleSheet.create({
  outerShadow: {
    borderRadius: 16,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.7,
    shadowRadius: 16,
    elevation: 12,
  },
  card: {
    borderRadius: 16,
    borderWidth: 1,
    borderColor: '#1e1e1e',
    overflow: 'hidden',
    position: 'relative',
  },
  edgeTop: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    height: 1,
    backgroundColor: 'rgba(255,255,255,0.10)',
    zIndex: 2,
  },
  edgeLeft: {
    position: 'absolute',
    top: 0,
    left: 0,
    bottom: 0,
    width: 1,
    backgroundColor: 'rgba(255,255,255,0.05)',
    zIndex: 2,
  },
  edgeRight: {
    position: 'absolute',
    top: 0,
    right: 0,
    bottom: 0,
    width: 1,
    backgroundColor: 'rgba(0,0,0,0.4)',
    zIndex: 2,
  },
  edgeBottom: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    height: 2,
    backgroundColor: 'rgba(0,0,0,0.5)',
    zIndex: 2,
  },
});
