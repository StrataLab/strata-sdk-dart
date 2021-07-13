import 'package:mubrambl/src/utils/address_utils.dart';
import 'package:test/test.dart';

void main() {
  group('validate addresses', () {
    setUp(() {
      // Additional setup goes here.
    });

    // test isValidNetwork success
    test('isValidNetwork success', () {
      final validationRes = isValidNetwork('private');
      expect(validationRes, true);
    });

    test('isValidNetwork failure empty', () {
      final validationRes = isValidNetwork('');
      expect(validationRes, false);
    });

    test('isValidNetwork failure wrong name', () {
      final validationRes = isValidNetwork('bifrost');
      expect(validationRes, false);
    });

// using a private address test to make sure that BramblDart validates properly
    test('validate address by network success private', () {
      final validationRes = validateAddressByNetwork(
          'private', 'AUAvJqLKc8Un3C6bC4aj8WgHZo74vamvX8Kdm6MhtdXgw51cGfix');

      expect(validationRes['success'], true);
    });

// using a valhalla address test to make sure that BramblDart validates properly
    test('validate address by network success valhalla', () {
      final validationRes = validateAddressByNetwork(
          'valhalla', '3NKunrdkLG6nEZ5EKqvxP5u4VjML3GBXk2UQgA9ad5Rsdzh412Dk');

      expect(validationRes['success'], true);
    });

    // using a toplnet address test to make sure that BramblDart validates properly

    test('validate address by network success toplnet', () {
      final validationRes = validateAddressByNetwork(
          'toplnet', '9d3Ny7sXoezon5DkAEqkHRjmZCitVLLdoTMqAKhRiKDWU8YZfax');

      expect(validationRes['success'], true);
    });

    // validate addresses empty address
    test('validate address by network failure empty address', () {
      final validationRes = validateAddressByNetwork('private', '');

      expect(validationRes['success'], false);
      expect(validationRes['errorMsg'], 'No addresses provided');
    });

    // validate addresses invalid network
    test('validate address by network failure invalid network', () {
      final validationRes = validateAddressByNetwork(
          'bifrost', '9d3Ny7sXoezon5DkAEqkHRjmZCitVLLdoTMqAKhRiKDWU8YZfax');

      expect(validationRes['success'], false);
      expect(validationRes['errorMsg'], 'Invalid network provided');
    });

    // validate addresses failure address too short
    test('validate address by network failure too short', () {
      final validationRes = validateAddressByNetwork(
          'toplnet', '9d3Ny7sXoezon5DkAEqkHRjmZCitVLLdoTMqAKhRiKDWU8YZfx');

      expect(validationRes['success'], false);
      expect(validationRes['errorMsg'], 'Invalid address for network: toplnet');
    });

    // validate addresses failure address too long
    test('validate address by network failure too long', () {
      final validationRes = validateAddressByNetwork(
          'toplnet', '9d3Ny7sXoezon5DkAEqkHRjmZCitVLLdoTMqAKhRiKDWU8YZfffff');

      expect(validationRes['success'], false);
      expect(validationRes['errorMsg'], 'Invalid address for network: toplnet');
    });

    // validate addresses failure address wrong network decimal
    test('validate address by network failure wrong network decimal', () {
      final validationRes = validateAddressByNetwork(
          'toplnet', '3NKunrdkLG6nEZ5EKqvxP5u4VjML3GBXk2UQgA9ad5Rsdzh412Dk');

      expect(validationRes['success'], false);
      expect(validationRes['errorMsg'], 'Invalid address for network: toplnet');
    });

    // validate addresses failure address invalid checksum
    test('validate address by network failure invalid checksum', () {
      final validationRes = validateAddressByNetwork(
          'valhalla', '3NKunrdUtKdWRXz33PazioBLgc7uynUQkM1bwLUfURpxt6V99VRQ');

      expect(validationRes['success'], false);
      expect(
          validationRes['errorMsg'], 'Addresses with invalid checksums found');
    });
  });
}
