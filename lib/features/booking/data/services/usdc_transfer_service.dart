import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:privy_flutter/privy_flutter.dart' hide AuthState;
import 'package:qent/core/services/privy_manager.dart';

/// V2 §4.1 Phase 2 — send a USDC ERC-20 transfer on Base from the
/// renter's embedded Privy wallet to the platform escrow.
///
/// Returns the on-chain `tx_hash` Privy reports plus the wallet
/// address it was sent from (which the backend asserts matches
/// `payments.from_address`).
class UsdcTransferResult {
  final String txHash;
  final String fromAddress;
  const UsdcTransferResult({required this.txHash, required this.fromAddress});
}

class UsdcTransferException implements Exception {
  final String message;
  UsdcTransferException(this.message);
  @override
  String toString() => message;
}

class UsdcTransferService {
  /// `0xa9059cbb` — selector for `transfer(address,uint256)`.
  static const _erc20TransferSelector = 'a9059cbb';

  static const _mainnetUsdc = '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913';
  static const _mainnetChainIdHex = '0x2105';

  /// USDC ERC-20 contract for the active chain. Read from .env so
  /// flipping between Base Mainnet and Base Sepolia is one variable.
  final String usdcContract;

  /// Active chain ID in hex form (Mainnet `0x2105`, Sepolia `0x14a34`).
  final String chainIdHex;

  UsdcTransferService({String? usdcContract, String? chainIdHex})
      : usdcContract = usdcContract ??
            (dotenv.env['BASE_USDC_CONTRACT']?.trim().isNotEmpty == true
                ? dotenv.env['BASE_USDC_CONTRACT']!.trim()
                : _mainnetUsdc),
        chainIdHex = chainIdHex ??
            (dotenv.env['BASE_CHAIN_ID_HEX']?.trim().isNotEmpty == true
                ? dotenv.env['BASE_CHAIN_ID_HEX']!.trim()
                : _mainnetChainIdHex);

  Future<UsdcTransferResult> sendToEscrow({
    required String destination,
    required String amountUsdc,
  }) async {
    if (!privyManager.isReady) {
      throw UsdcTransferException(
        privyManager.initErrorMessage ?? 'Privy not configured',
      );
    }

    final user = await privyManager.privy.getUser();
    if (user == null) {
      throw UsdcTransferException('Not signed in');
    }

    final wallet = _firstEthereumWallet(user);
    if (wallet == null) {
      throw UsdcTransferException(
        'No embedded Ethereum wallet on this account',
      );
    }

    final data = _encodeErc20Transfer(
      destination: destination,
      amountUsdc: amountUsdc,
    );

    final tx = {
      'from': wallet.address,
      'to': usdcContract,
      'value': '0x0',
      'data': data,
      'chainId': chainIdHex,
    };

    final request = EthereumRpcRequest(
      method: 'eth_sendTransaction',
      params: [jsonEncode(tx)],
    );

    String? txHash;
    String? error;
    final result = await wallet.provider.request(request);
    result.fold(
      onSuccess: (resp) {
        // The Privy SDK returns the raw eth_sendTransaction result —
        // a 0x-prefixed 66-char tx_hash — as `resp.data`.
        txHash = resp.data;
      },
      onFailure: (e) => error = e.message,
    );

    if (txHash == null || !txHash!.startsWith('0x')) {
      throw UsdcTransferException(error ?? 'Privy did not return a tx_hash');
    }
    return UsdcTransferResult(
      txHash: txHash!,
      fromAddress: wallet.address.toLowerCase(),
    );
  }

  EmbeddedEthereumWallet? _firstEthereumWallet(PrivyUser user) {
    try {
      // The SDK exposes embedded wallets via `embeddedEthereumWallets`.
      // Older SDK versions used `ethereumWallets`; both return the same.
      final list = user.embeddedEthereumWallets;
      if (list.isNotEmpty) return list.first;
    } catch (e) {
      debugPrint('[Qent USDC] could not read embeddedEthereumWallets: $e');
    }
    return null;
  }

  /// Encode the ERC-20 `transfer(address,uint256)` calldata.
  ///   selector(4) || padded(to)(32) || padded(amount_raw)(32)
  ///
  /// USDC has 6 decimals → raw = floor(amountUsdc * 10^6).
  String _encodeErc20Transfer({
    required String destination,
    required String amountUsdc,
  }) {
    final to = destination.toLowerCase().replaceFirst('0x', '');
    if (to.length != 40) {
      throw UsdcTransferException('Bad destination address');
    }
    final paddedTo = to.padLeft(64, '0');

    final raw = _usdcToRawUnits(amountUsdc);
    final paddedAmt = raw.toRadixString(16).padLeft(64, '0');

    return '0x$_erc20TransferSelector$paddedTo$paddedAmt';
  }

  /// "52.55" → 52_550_000  (USDC has 6 decimals)
  BigInt _usdcToRawUnits(String amount) {
    final parts = amount.trim().split('.');
    final whole = BigInt.parse(parts[0]);
    final fracStr = parts.length > 1 ? parts[1] : '';
    final padded = '${fracStr}000000'.substring(0, 6);
    final frac = BigInt.parse(padded);
    return whole * BigInt.from(1000000) + frac;
  }
}
