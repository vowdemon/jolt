import "package:jolt/jolt.dart";
import "package:test/test.dart";

void main() {
  group("AsyncState", () {
    test("should create AsyncLoading state", () {
      const state = AsyncLoading<int>();

      expect(state.isLoading, isTrue);
      expect(state.isSuccess, isFalse);
      expect(state.isError, isFalse);
      expect(state.data, isNull);
      expect(state.error, isNull);
      expect(state.stackTrace, isNull);
    });

    test("should create AsyncSuccess state", () {
      const state = AsyncSuccess<int>(42);

      expect(state.isLoading, isFalse);
      expect(state.isSuccess, isTrue);
      expect(state.isError, isFalse);
      expect(state.data, equals(42));
      expect(state.error, isNull);
      expect(state.stackTrace, isNull);
    });

    test("should create AsyncError state", () {
      final error = Exception("Test error");
      final stackTrace = StackTrace.current;
      final state = AsyncError<int>(error, stackTrace);

      expect(state.isLoading, isFalse);
      expect(state.isSuccess, isFalse);
      expect(state.isError, isTrue);
      expect(state.data, isNull);
      expect(state.error, equals(error));
      expect(state.stackTrace, equals(stackTrace));
    });

    test("should map AsyncLoading state", () {
      const state = AsyncLoading<int>();

      final result = state.map<String>(
        loading: () => "loading",
        success: (data) => "success: $data",
        error: (error, stackTrace) => "error: $error",
      );

      expect(result, equals("loading"));
    });

    test("should map AsyncSuccess state", () {
      const state = AsyncSuccess<int>(42);

      final result = state.map<String>(
        loading: () => "loading",
        success: (data) => "success: $data",
        error: (error, stackTrace) => "error: $error",
      );

      expect(result, equals("success: 42"));
    });

    test("should map AsyncError state", () {
      final error = Exception("Test error");
      final state = AsyncError<int>(error);

      final result = state.map<String>(
        loading: () => "loading",
        success: (data) => "success: $data",
        error: (error, stackTrace) => "error: $error",
      );

      expect(result, equals("error: Exception: Test error"));
    });
  });
}
