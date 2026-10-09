/**
 * XLog - 简洁高效的日志工具
 *
 * 统一管理应用日志输出，支持不同级别的日志记录
 */
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0001; // 应用日志域
const APP_TAG = 'Alive'; // 应用标识

export class XLog {
  private static enableDebug: boolean = true;

  static setDebugEnabled(enabled: boolean): void {
    XLog.enableDebug = enabled;
  }

  static d(tag: string, message: string): void {
    if (!XLog.enableDebug) {
      return;
    }
    hilog.debug(DOMAIN, APP_TAG, `[${tag}] ${message}`);
  }

  static i(tag: string, message: string, error: Error | undefined = undefined): void {
    hilog.info(DOMAIN, APP_TAG, `[${tag}] ${message}`, error);
  }

  static w(tag: string, message: string): void {
    hilog.warn(DOMAIN, APP_TAG, `[${tag}] ${message}`);
  }

  static e(tag: string, message: string, error: Error | undefined = undefined): void {
    hilog.error(DOMAIN, APP_TAG, `[${tag}] ${message}`, error);
  }

  static f(tag: string, message: string, error: Error | undefined = undefined): void {
    hilog.fatal(DOMAIN, APP_TAG, `[${tag}] ${message}`, error);
  }

  static toJson(obj: ESObject): string {
    try {
      return JSON.stringify(obj);
    } catch (_e) {
      return String(obj);
    }
  }

  static enter(tag: string, methodName: string): void {
    XLog.d(tag, `→ ${methodName}`);
  }

  static exit(tag: string, methodName: string): void {
    XLog.d(tag, `← ${methodName}`);
  }
}
