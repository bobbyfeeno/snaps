import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';

export default function RootLayout() {
  return (
    <>
      <StatusBar style="light" />
      <Stack
        screenOptions={{
          headerStyle: { backgroundColor: '#0d1f0d' },
          headerTintColor: '#39FF14',
          headerTitleStyle: { fontWeight: '700', color: '#fff' },
          animation: 'slide_from_right',
        }}
      >
        <Stack.Screen name="index" options={{ headerShown: false }} />
        <Stack.Screen name="setup" options={{ title: 'Game Setup' }} />
        <Stack.Screen name="scores" options={{ title: 'Enter Scores' }} />
        <Stack.Screen name="results" options={{ title: 'Results' }} />
      </Stack>
    </>
  );
}
